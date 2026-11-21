module rv32im_lsu_lsq_fsm_g #(
    parameter int UW = 251
) (
    input  logic clk,
    input  logic rst_n,

    input  logic          d_req_ready,
    input  logic          d_resp_valid,
    input  logic [31:0]   d_resp_rdata,
    input  logic          d_resp_error,
    input  logic          flush,
    input  logic          ld0,
    input  logic          ld1,
    input  logic          st0,
    input  logic          st1,
    input  logic          disp_rob_valid0,
    input  logic          disp_rob_valid1,
    input  logic          disp_fire0,
    input  logic          disp_fire1,
    input  logic [4:0]    rob_idx0,
    input  logic [4:0]    rob_idx1,
    input  logic [5:0]    rob_occ,
    input  logic          rob_empty,
    input  logic          rob_cv0,
    input  logic [4:0]    rob_cidx0,
    input  logic          mq_issue_valid0,
    input  logic          mq_issue_valid1,
    input  logic          mq_is_load0,
    input  logic          mq_is_load1,
    input  logic          mq_is_store0,
    input  logic          mq_is_store1,
    input  logic [1:0]    mq_size0,
    input  logic [1:0]    mq_size1,
    input  logic [31:0]   mq_base0,
    input  logic [31:0]   mq_base1,
    input  logic [31:0]   mq_sdata0,
    input  logic [31:0]   mq_sdata1,
    input  logic [31:0]   mq_imm0,
    input  logic [31:0]   mq_imm1,
    input  logic [4:0]    mq_rob0,
    input  logic [4:0]    mq_rob1,
    input  logic          cs_ret_valid0,
    input  logic [4:0]    cs_ret_idx0,
    input  logic          cs_ret_valid1,
    input  logic [4:0]    cs_ret_idx1,
    input  logic [UW-1:0] tbl_cm_data0,
    input  logic [UW-1:0] tbl_cm_data1,
    input  logic [UW-1:0] tbl_ld_data,
    input  logic [31:0]   tbl_is_load_vec,
    input  logic [31:0]   tbl_is_store_vec,

    output logic        d_req_valid,
    output logic        d_req_write,
    output logic [31:0] d_req_addr,
    output logic [31:0] d_req_wdata,
    output logic [1:0]  d_req_size,
    output logic        d_resp_ready,
    output logic        mq_issue_ready0,
    output logic        mq_issue_ready1,
    output logic        mem_c_valid,
    output logic [5:0]  mem_c_pdst,
    output logic [31:0] mem_c_data,
    output logic [4:0]  mem_c_rob,
    output logic        mem_c_wr,
    output logic        mem_c_exc,
    output logic [31:0] mem_c_cause,
    output logic [4:0]  lq_count,
    output logic [4:0]  sq_count,
    output logic [4:0]  ld_tag5
);

    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] pred_pc;
        logic [31:0] imm;
        logic [31:0] instr;
        logic [31:0] src1_data;
        logic [31:0] src2_data;
        logic [4:0] rd;
        logic [5:0] pdst;
        logic [5:0] old_pdst;
        logic [5:0] psrc1;
        logic [5:0] psrc2;
        logic [4:0] alu_op;
        logic [2:0] funct3;
        logic [3:0] ghist;
        logic [1:0] msize;
        logic src1_ready;
        logic src2_ready;
        logic writes_rd;
        logic uses_rs2;
        logic is_auipc;
        logic is_branch;
        logic is_jal;
        logic is_jalr;
        logic is_load;
        logic is_store;
        logic is_muldiv;
        logic is_system;
        logic is_fence;
        logic illegal;
        logic load_unsigned;
        logic pred_taken;
    } uop_t;

    localparam logic [2:0] M_IDLE = 3'd0;
    localparam logic [2:0] M_REQ = 3'd1;
    localparam logic [2:0] M_WAIT = 3'd2;
    localparam logic [2:0] M_LDRES = 3'd3;
    localparam logic [2:0] M_EXC = 3'd4;

    logic        mq_fire0;
    logic        mq_fire1;
    logic [2:0]  mstate;
    logic        m_is_load;
    logic [5:0]  m_pdst;
    logic [4:0]  m_rob;
    logic        m_wr;
    logic [1:0]  m_size;
    logic        m_unsigned;
    logic [31:0] m_addr;
    logic [31:0] m_data;
    logic        m_err;
    logic        m_misaligned;
    logic        m_launch;
    logic        m_launch_load;
    logic        m_launch_store;
    uop_t head_u;
    logic        lsu_req_valid;
    logic        lsu_req_ready;
    logic        lsu_mem_req_valid;
    logic        lsu_mem_req_ready;
    logic        lsu_mem_req_write;
    logic [31:0] lsu_mem_req_addr;
    logic [31:0] lsu_mem_req_wdata;
    logic [3:0]  lsu_mem_req_strb;
    logic        lsu_mem_rsp_valid;
    logic        lsu_result_valid;
    logic [31:0] lsu_result_data;
    logic        lsu_busy;
    logic        lsu_misaligned;
    logic        lq_alloc_valid;
    logic        lq_alloc_ready;
    logic [5:0]  lq_alloc_tag;
    logic        sq_alloc_valid;
    logic        sq_alloc_ready;
    logic [5:0]  sq_alloc_tag;
    logic        lq_retire_valid;
    logic [5:0]  lq_retire_tag;
    logic        sq_retire_valid;
    logic [5:0]  sq_retire_tag;
    logic        lq_upd_valid;
    logic [5:0]  lq_upd_tag;
    logic [31:0] lq_upd_addr;
    logic        sq_upd_valid;
    logic [5:0]  sq_upd_tag;
    logic [31:0] sq_upd_addr;
    logic [31:0] sq_upd_data;
    logic [3:0]  sq_upd_wstrb;
    logic        lq_head_valid;
    logic [5:0]  lq_head_tag;
    logic [31:0] lq_head_addr;
    logic [31:0] lq_head_data;
    logic        lq_head_addr_valid;
    logic        lq_head_data_valid;
    logic        sq_head_valid;
    logic [5:0]  sq_head_tag;
    logic [31:0] sq_head_addr;
    logic [31:0] sq_head_data;
    logic [3:0]  sq_head_wstrb;
    logic        sq_head_addr_valid;
    logic        sq_head_data_valid;
    logic        lq_full;
    logic        lq_empty;
    logic        sq_full;
    logic        sq_empty;
    logic [4:0]  ld_dist;
    logic [4:0]  sq_dist;
    logic        older_store;
    uop_t ld_u;
    uop_t lu;
    logic [4:0]  ld_pick;
    logic [4:0]  scan_idx;
    logic        scan_found;
    logic        scan_blocked;
    logic        ld_ready;
    logic        m_free;
    logic        m_squash;
    logic        m_last_valid;
    logic [4:0]  m_last_tag;
    logic [31:0] ld_av;
    logic [31:0] ld_launched;
    logic [31:0] ld_addr_tbl [0:31];
    logic [31:0] ld_addr_sel;

    always_comb begin
        mq_issue_ready0 = !flush;
        mq_issue_ready1 = !flush &&
                          !(mq_issue_valid0 &&
                            ((mq_is_load0 && mq_is_load1) || (mq_is_store0 && mq_is_store1)));
        mq_fire0 = mq_issue_valid0 && mq_issue_ready0;
        mq_fire1 = mq_issue_valid1 && mq_issue_ready1;

        lq_upd_valid = 1'b0;
        lq_upd_tag = 6'd0;
        lq_upd_addr = 32'd0;
        sq_upd_valid = 1'b0;
        sq_upd_tag = 6'd0;
        sq_upd_addr = 32'd0;
        sq_upd_data = 32'd0;
        sq_upd_wstrb = 4'd0;

        if (mq_fire0 && mq_is_load0) begin
            lq_upd_valid = 1'b1;
            lq_upd_tag = {1'b0, mq_rob0};
            lq_upd_addr = mq_base0 + mq_imm0;
        end
        if (mq_fire1 && mq_is_load1) begin
            lq_upd_valid = 1'b1;
            lq_upd_tag = {1'b0, mq_rob1};
            lq_upd_addr = mq_base1 + mq_imm1;
        end
        if (mq_fire0 && mq_is_store0) begin
            sq_upd_valid = 1'b1;
            sq_upd_tag = {1'b0, mq_rob0};
            sq_upd_addr = mq_base0 + mq_imm0;
            sq_upd_data = mq_sdata0;
            sq_upd_wstrb = (mq_size0 == 2'b00) ? (4'b0001 << (mq_base0[1:0] + mq_imm0[1:0])) :
                           (mq_size0 == 2'b01) ? (4'b0011 << (mq_base0[1:0] + mq_imm0[1:0])) : 4'b1111;
        end
        if (mq_fire1 && mq_is_store1) begin
            sq_upd_valid = 1'b1;
            sq_upd_tag = {1'b0, mq_rob1};
            sq_upd_addr = mq_base1 + mq_imm1;
            sq_upd_data = mq_sdata1;
            sq_upd_wstrb = (mq_size1 == 2'b00) ? (4'b0001 << (mq_base1[1:0] + mq_imm1[1:0])) :
                           (mq_size1 == 2'b01) ? (4'b0011 << (mq_base1[1:0] + mq_imm1[1:0])) : 4'b1111;
        end

        lq_alloc_valid = (disp_fire0 && ld0) || (disp_fire1 && ld1);
        lq_alloc_tag = (disp_fire0 && ld0) ? {1'b0, rob_idx0} : {1'b0, rob_idx1};
        sq_alloc_valid = (disp_fire0 && st0) || (disp_fire1 && st1);
        sq_alloc_tag = (disp_fire0 && st0) ? {1'b0, rob_idx0} : {1'b0, rob_idx1};

        lq_retire_valid = 1'b0;
        lq_retire_tag = 6'd0;
        sq_retire_valid = 1'b0;
        sq_retire_tag = 6'd0;
        if (cs_ret_valid1 && lcu1.is_load) begin
            lq_retire_valid = 1'b1;
            lq_retire_tag = {1'b0, cs_ret_idx1};
        end
        if (cs_ret_valid1 && lcu1.is_store) begin
            sq_retire_valid = 1'b1;
            sq_retire_tag = {1'b0, cs_ret_idx1};
        end
        if (cs_ret_valid0 && lcu0.is_load) begin
            lq_retire_valid = 1'b1;
            lq_retire_tag = {1'b0, cs_ret_idx0};
        end
        if (cs_ret_valid0 && lcu0.is_store) begin
            sq_retire_valid = 1'b1;
            sq_retire_tag = {1'b0, cs_ret_idx0};
        end
    end

    rv32im_lsq_g u_lsq (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .load_alloc_valid(lq_alloc_valid),
        .load_alloc_ready(lq_alloc_ready),
        .load_alloc_rob_tag(lq_alloc_tag),
        .store_alloc_valid(sq_alloc_valid),
        .store_alloc_ready(sq_alloc_ready),
        .store_alloc_rob_tag(sq_alloc_tag),
        .load_retire_valid(lq_retire_valid),
        .load_retire_rob_tag(lq_retire_tag),
        .store_retire_valid(sq_retire_valid),
        .store_retire_rob_tag(sq_retire_tag),
        .load_update_valid(lq_upd_valid),
        .load_update_rob_tag(lq_upd_tag),
        .load_update_addr(lq_upd_addr),
        .load_update_data(32'd0),
        .load_update_addr_valid(1'b1),
        .load_update_data_valid(1'b1),
        .store_update_valid(sq_upd_valid),
        .store_update_rob_tag(sq_upd_tag),
        .store_update_addr(sq_upd_addr),
        .store_update_data(sq_upd_data),
        .store_update_wstrb(sq_upd_wstrb),
        .store_update_addr_valid(1'b1),
        .store_update_data_valid(1'b1),
        .load_head_valid(lq_head_valid),
        .load_head_rob_tag(lq_head_tag),
        .load_head_addr(lq_head_addr),
        .load_head_data(lq_head_data),
        .load_head_addr_valid(lq_head_addr_valid),
        .load_head_data_valid(lq_head_data_valid),
        .store_head_valid(sq_head_valid),
        .store_head_rob_tag(sq_head_tag),
        .store_head_addr(sq_head_addr),
        .store_head_data(sq_head_data),
        .store_head_wstrb(sq_head_wstrb),
        .store_head_addr_valid(sq_head_addr_valid),
        .store_head_data_valid(sq_head_data_valid),
        .load_full(lq_full),
        .load_empty(lq_empty),
        .load_count(lq_count),
        .store_full(sq_full),
        .store_empty(sq_empty),
        .store_count(sq_count)
    );

    localparam int LOAD_MODE = 2;
    localparam bit B2B = 1'b1;

    always_comb begin
        head_u = tbl_cm_s0;
        scan_found = 1'b0;
        scan_blocked = 1'b0;
        scan_idx = '0;
        ld_pick = rob_cidx0;
        for (int k = 0; k < 32; k = k + 1) begin
            scan_idx = rob_cidx0 + 5'(k);
            if (!scan_found && !scan_blocked && (6'(k) < rob_occ)) begin
                if (tbl_is_store_vec[scan_idx])
                    scan_blocked = 1'b1;
                else if (tbl_is_load_vec[scan_idx] && ld_av[scan_idx] && !ld_launched[scan_idx]) begin
                    scan_found = 1'b1;
                    ld_pick = scan_idx;
                end
            end
        end
        ld_dist = '0;
        sq_dist = '0;
        older_store = 1'b0;
        if (LOAD_MODE == 2) begin
            ld_ready = scan_found;
            ld_tag5 = ld_pick;
            ld_addr_sel = ld_addr_tbl[ld_pick];
        end else if (LOAD_MODE == 1) begin
            ld_tag5 = lq_head_tag[4:0];
            ld_dist = ld_tag5 - rob_cidx0;
            sq_dist = sq_head_tag[4:0] - rob_cidx0;
            older_store = sq_head_valid && (sq_dist < ld_dist);
            ld_ready = lq_head_valid && lq_head_addr_valid && !older_store &&
                       tbl_ld_s.is_load &&
                       !(m_last_valid && (m_last_tag == ld_tag5));
            ld_addr_sel = lq_head_addr;
        end else begin
            ld_ready = !rob_cv0 && head_u.is_load && lq_head_valid &&
                       (lq_head_tag == {1'b0, rob_cidx0}) && lq_head_addr_valid;
            ld_tag5 = rob_cidx0;
            ld_addr_sel = lq_head_addr;
        end
        ld_u = tbl_ld_s;

        m_free = (mstate == M_IDLE) || (B2B && mstate == M_WAIT && d_resp_valid);
        m_launch_load = m_free && !flush && !rob_empty && ld_ready;

        m_launch_store = (mstate == M_IDLE) && !flush && !rob_empty && !rob_cv0 &&
                         head_u.is_store && sq_head_valid &&
                         (sq_head_tag == {1'b0, rob_cidx0}) &&
                         sq_head_addr_valid && sq_head_data_valid;
        m_launch = m_launch_load || m_launch_store;
        lu = m_launch_load ? ld_u : head_u;
        m_misaligned = 1'b0;
        if (m_launch_load) begin
            if (lu.msize == 2'b01 && ld_addr_sel[0])
                m_misaligned = 1'b1;
            if (lu.msize == 2'b10 && ld_addr_sel[1:0] != 2'b00)
                m_misaligned = 1'b1;
        end
        if (m_launch_store) begin
            if (lu.msize == 2'b01 && sq_head_addr[0])
                m_misaligned = 1'b1;
            if (lu.msize == 2'b10 && sq_head_addr[1:0] != 2'b00)
                m_misaligned = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ld_av <= '0;
            ld_launched <= '0;
        end else if (flush) begin
            ld_av <= '0;
            ld_launched <= '0;
        end else begin
            if (disp_rob_valid0) begin
                ld_av[rob_idx0] <= 1'b0;
                ld_launched[rob_idx0] <= 1'b0;
            end
            if (disp_rob_valid1) begin
                ld_av[rob_idx1] <= 1'b0;
                ld_launched[rob_idx1] <= 1'b0;
            end
            if (lq_upd_valid) begin
                ld_av[lq_upd_tag[4:0]] <= 1'b1;
                ld_addr_tbl[lq_upd_tag[4:0]] <= lq_upd_addr;
            end
            if (m_launch_load)
                ld_launched[ld_pick] <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstate <= M_IDLE;
            m_is_load <= 1'b0;
            m_pdst <= '0;
            m_rob <= '0;
            m_wr <= 1'b0;
            m_size <= 2'b10;
            m_unsigned <= 1'b0;
            m_addr <= '0;
            m_data <= '0;
            m_err <= 1'b0;
            m_squash <= 1'b0;
            m_last_valid <= 1'b0;
            m_last_tag <= 5'd0;
        end else begin
            case (mstate)
                M_IDLE: begin
                    if (m_launch) begin
                        m_is_load <= m_launch_load;
                        m_pdst <= lu.pdst;
                        m_rob <= m_launch_load ? ld_tag5 : rob_cidx0;
                        m_wr <= lu.writes_rd;
                        m_size <= lu.msize;
                        m_unsigned <= lu.load_unsigned;
                        m_addr <= m_launch_load ? ld_addr_sel : sq_head_addr;
                        m_data <= sq_head_data;
                        m_err <= 1'b0;
                        mstate <= m_misaligned ? M_EXC : M_REQ;
                    end
                end
                M_REQ: begin
                    if (lsu_req_ready)
                        mstate <= M_WAIT;
                end
                M_WAIT: begin
                    if (d_resp_valid) begin
                        m_err <= d_resp_error;
                        mstate <= M_IDLE;
                    end
                end
                M_LDRES: mstate <= M_IDLE;
                M_EXC: mstate <= M_IDLE;
                default: mstate <= M_IDLE;
            endcase

            if (m_launch && mstate == M_WAIT && d_resp_valid) begin
                m_is_load <= m_launch_load;
                m_pdst <= lu.pdst;
                m_rob <= m_launch_load ? ld_tag5 : rob_cidx0;
                m_wr <= lu.writes_rd;
                m_size <= lu.msize;
                m_unsigned <= lu.load_unsigned;
                m_addr <= m_launch_load ? ld_addr_sel : sq_head_addr;
                m_data <= sq_head_data;
                m_err <= 1'b0;
                mstate <= m_misaligned ? M_EXC : M_REQ;
            end
            if (m_launch_load) begin
                m_last_valid <= 1'b1;
                m_last_tag <= ld_tag5;
            end
            if (lq_retire_valid && m_last_valid && (lq_retire_tag[4:0] == m_last_tag))
                m_last_valid <= 1'b0;
            if (m_launch)
                m_squash <= 1'b0;
            if (flush) begin
                m_last_valid <= 1'b0;
                if (m_is_load && mstate != M_IDLE && mstate != M_EXC &&
                    !(mstate == M_WAIT && d_resp_valid))
                    m_squash <= 1'b1;
            end
        end
    end

    rv32im_lsu_g #(
        .ADDR_BITS(32),
        .DATA_BITS(32)
    ) u_lsu (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(lsu_req_valid),
        .req_ready(lsu_req_ready),
        .req_is_load(m_is_load),
        .req_is_store(!m_is_load),
        .req_size(m_size),
        .req_unsigned(m_unsigned),
        .req_base(m_addr),
        .req_immediate(32'd0),
        .req_store_data(m_data),
        .mem_req_valid(lsu_mem_req_valid),
        .mem_req_ready(lsu_mem_req_ready),
        .mem_req_write(lsu_mem_req_write),
        .mem_req_addr(lsu_mem_req_addr),
        .mem_req_wdata(lsu_mem_req_wdata),
        .mem_req_strb(lsu_mem_req_strb),
        .mem_rsp_valid(lsu_mem_rsp_valid),
        .mem_rsp_rdata(d_resp_rdata),
        .result_valid(lsu_result_valid),
        .result_data(lsu_result_data),
        .busy(lsu_busy),
        .misaligned(lsu_misaligned)
    );

    always_comb begin
        lsu_req_valid = (mstate == M_REQ);
        lsu_mem_req_ready = d_req_ready;
        lsu_mem_rsp_valid = d_resp_valid && (mstate == M_WAIT);
        d_req_valid = lsu_mem_req_valid;
        d_req_write = lsu_mem_req_write;
        d_req_addr = lsu_mem_req_write ? m_addr : lsu_mem_req_addr;
        d_req_size = lsu_mem_req_write ? m_size : 2'b10;
        d_req_wdata = m_data;
        d_resp_ready = 1'b1;

        mem_c_valid = 1'b0;
        mem_c_pdst = 6'd0;
        mem_c_data = 32'd0;
        mem_c_rob = m_rob;
        mem_c_wr = 1'b0;
        mem_c_exc = 1'b0;
        mem_c_cause = 32'd0;
        if (mstate == M_WAIT && d_resp_valid && !m_is_load) begin
            mem_c_valid = 1'b1;
            mem_c_exc = d_resp_error;
            mem_c_cause = 32'd7;
        end
        if (mstate == M_WAIT && d_resp_valid && m_is_load) begin

            mem_c_valid = 1'b1;
            mem_c_data = lsu_result_data;
            mem_c_pdst = m_pdst;
            mem_c_wr = m_wr && !d_resp_error;
            mem_c_exc = d_resp_error;
            mem_c_cause = 32'd5;
        end
        if (mstate == M_EXC) begin
            mem_c_valid = 1'b1;
            mem_c_exc = 1'b1;
            mem_c_cause = m_is_load ? 32'd4 : 32'd6;
        end

        if (m_is_load && (m_squash || flush))
            mem_c_valid = 1'b0;
    end

    uop_t tbl_cm_s0;
    uop_t tbl_ld_s;
    uop_t lcu0;
    uop_t lcu1;
    assign tbl_cm_s0 = tbl_cm_data0;
    assign tbl_ld_s = tbl_ld_data;
    assign lcu0 = tbl_cm_data0;
    assign lcu1 = tbl_cm_data1;

endmodule