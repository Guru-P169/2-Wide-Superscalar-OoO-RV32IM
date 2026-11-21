module rv32im_exec_alu_bru_wb_g #(
    parameter int UW = 251
) (
    input  logic clk,
    input  logic rst_n,

    input  logic          flush,
    input  logic          iq_issue_valid0,
    input  logic          iq_issue_valid1,
    input  logic [4:0]    iq_op0,
    input  logic [4:0]    iq_op1,
    input  logic [5:0]    iq_pdst0,
    input  logic [5:0]    iq_pdst1,
    input  logic [31:0]   iq_src1_0,
    input  logic [31:0]   iq_src1_1,
    input  logic [31:0]   iq_src2_0,
    input  logic [31:0]   iq_src2_1,
    input  logic [31:0]   iq_imm0,
    input  logic [31:0]   iq_imm1,
    input  logic [4:0]    iq_rob0,
    input  logic [4:0]    iq_rob1,
    input  logic          md_req_ready,
    input  logic          md_rsp_valid,
    input  logic [31:0]   md_rsp_result,
    input  logic          mem_c_valid,
    input  logic [5:0]    mem_c_pdst,
    input  logic [31:0]   mem_c_data,
    input  logic [4:0]    mem_c_rob,
    input  logic          mem_c_wr,
    input  logic          mem_c_exc,
    input  logic [31:0]   mem_c_cause,
    input  logic [31:0]   csr_read_data,
    input  logic [UW-1:0] tbl_ex_data0,
    input  logic [UW-1:0] tbl_ex_data1,

    output logic        pr_update_valid,
    output logic [31:0] pr_update_pc,
    output logic [3:0]  pr_update_hist,
    output logic        pr_update_taken,
    output logic [31:0] pr_update_target,
    output logic        iq_issue_ready0,
    output logic        iq_issue_ready1,
    output logic [1:0]  ex_ctl,
    output logic [1:0]  ex_fire,
    output logic [1:0]  br_mis,
    output logic [9:0]  ex_rob_flat,
    output logic [63:0] br_rpc_flat,
    output logic        md_req_valid,
    output logic [2:0]  md_req_f3,
    output logic [31:0] md_req_a,
    output logic [31:0] md_req_b,
    output logic        md_rsp_ready,
    output logic [1:0]  lane_exc,
    output logic [63:0] lane_cause_flat,
    output logic        wk_valid0,
    output logic        wk_valid1,
    output logic [5:0]  wk_pdst0,
    output logic [5:0]  wk_pdst1,
    output logic [31:0] wk_data0,
    output logic [31:0] wk_data1,
    output logic        prf_we0,
    output logic        prf_we1,
    output logic [5:0]  prf_waddr0,
    output logic [5:0]  prf_waddr1,
    output logic [31:0] prf_wdata0,
    output logic [31:0] prf_wdata1,
    output logic        cb_v0,
    output logic        cb_v1,
    output logic [4:0]  cb_tag0,
    output logic [4:0]  cb_tag1,
    output logic [31:0] cb_res0,
    output logic [31:0] cb_res1,
    output logic        csr_read_valid,
    output logic [11:0] csr_read_addr,
    output logic        csr_write_valid,
    output logic [11:0] csr_write_addr,
    output logic [31:0] csr_write_data,
    output logic [2:0]  csr_write_cmd
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

    logic [1:0]  ex_v;
    logic [1:0]  ex_md;
    logic [1:0]  ex_sys;
    logic [1:0]  ex_csr;
    logic [1:0]  ex_exc;
    logic [1:0]  ex_misal;
    logic [1:0]  ex_wr;
    logic [1:0]  ex_ready;
    logic [1:0]  ex_sel;
    logic [1:0]  md_take;
    logic [1:0]  bu_taken;
    logic [1:0]  bu_redirect;
    logic [4:0]  ex_op [0:1];
    logic [5:0]  ex_pdst [0:1];
    logic [31:0] ex_s1 [0:1];
    logic [31:0] ex_s2 [0:1];
    logic [31:0] ex_imm [0:1];
    logic [31:0] ex_a [0:1];
    logic [31:0] ex_b [0:1];
    logic [31:0] ex_res [0:1];
    logic [31:0] ex_next [0:1];
    logic [31:0] ex_cause [0:1];
    logic [31:0] alu_res [0:1];
    logic [31:0] bu_target [0:1];
    logic [31:0] bu_link [0:1];
    uop_t ex_u [0:1];
    logic [1:0]   alu_zero;
    logic [1:0]   alu_lt;
    logic [1:0]   alu_ltu;
    logic [1:0]   br_recov_valid;
    logic [1:0]   br_flush_fe;
    logic [1:0]   br_flush_dec;
    logic [1:0]   br_flush_ren;
    logic [1:0]   br_flush_iss;
    logic [4:0]   br_rtag [0:1];
    logic         md_cand0;
    logic         md_cand1;
    logic [5:0]   md_pdst;
    logic [4:0]   md_rob;
    logic         md_wr;
    logic [3:0]   ws_valid;
    logic [23:0]  ws_pdst;
    logic [127:0] ws_data;
    logic [1:0]   ws_out_valid;
    logic [11:0]  ws_out_pdst;
    logic [63:0]  ws_out_data;
    logic [3:0]   ws_out_index;
    logic [3:0]   ws_chosen;
    logic [4:0]   src_rob [0:3];
    logic [3:0]   src_wr;
    logic [3:0]   src_exc;
    logic [31:0]  src_cause [0:3];
    logic [5:0]   src_pdst [0:3];
    logic [31:0]  src_data [0:3];
    logic [1:0]   lane_v;
    logic [1:0]   lane_wr;
    logic [5:0]   lane_pdst [0:1];
    logic [31:0]  lane_data [0:1];
    logic [4:0]   lane_rob [0:1];
    logic [1:0]   lane_sel [0:1];
    logic         wb_cv0;
    logic         wb_cv1;
    logic [4:0]   wb_ctag0;
    logic [4:0]   wb_ctag1;
    logic [31:0]  wb_cres0;
    logic [31:0]  wb_cres1;
    logic         pu_v;
    logic [31:0]  pu_pc;
    logic [3:0]   pu_hist;
    logic         pu_taken;
    logic [31:0]  pu_tgt;
    logic         pu_nv;
    logic [31:0]  pu_npc;
    logic [3:0]   pu_nhist;
    logic         pu_ntaken;
    logic [31:0]  pu_ntgt;
    logic         f0v;
    logic         f1v;
    logic [4:0]   ex_rob [0:1];
    logic [31:0]  br_rpc [0:1];
    logic [31:0]  lane_cause [0:1];

    always_comb begin
        for (int fi = 0; fi < 2; fi = fi + 1)
            ex_rob_flat[fi*5 +: 5] = ex_rob[fi];
    end

    always_comb begin
        for (int fi = 0; fi < 2; fi = fi + 1)
            br_rpc_flat[fi*32 +: 32] = br_rpc[fi];
    end

    always_comb begin
        for (int fi = 0; fi < 2; fi = fi + 1)
            lane_cause_flat[fi*32 +: 32] = lane_cause[fi];
    end

    always_comb begin
        ex_v[0] = iq_issue_valid0 && !flush;
        ex_v[1] = iq_issue_valid1 && !flush;
        ex_rob[0] = iq_rob0;
        ex_rob[1] = iq_rob1;
        ex_op[0] = iq_op0;
        ex_op[1] = iq_op1;
        ex_pdst[0] = iq_pdst0;
        ex_pdst[1] = iq_pdst1;
        ex_s1[0] = iq_src1_0;
        ex_s1[1] = iq_src1_1;
        ex_s2[0] = iq_src2_0;
        ex_s2[1] = iq_src2_1;
        ex_imm[0] = iq_imm0;
        ex_imm[1] = iq_imm1;
        for (int i = 0; i < 2; i = i + 1) begin
            ex_u[i] = (i == 0) ? tbl_ex_s0 : tbl_ex_s1;
            ex_md[i] = ex_u[i].is_muldiv;
            ex_ctl[i] = ex_u[i].is_branch || ex_u[i].is_jal || ex_u[i].is_jalr;
            ex_sys[i] = ex_u[i].is_system;
            ex_csr[i] = ex_v[i] && ex_u[i].is_system && (ex_u[i].funct3 != 3'b000);
            ex_a[i] = ex_u[i].is_auipc ? ex_u[i].pc : ex_s1[i];
            ex_b[i] = ex_u[i].uses_rs2 ? ex_s2[i] : ex_imm[i];
            ex_wr[i] = ex_u[i].writes_rd;
            ex_misal[i] = ex_ctl[i] && bu_redirect[i] && (bu_target[i][1:0] != 2'b00);
            ex_exc[i] = ex_u[i].illegal || ex_misal[i] ||
                        (ex_u[i].is_system && (ex_u[i].funct3 == 3'b000) &&
                         (ex_u[i].instr[31:20] == 12'h000 || ex_u[i].instr[31:20] == 12'h001));
            ex_cause[i] = ex_u[i].illegal ? ((ex_u[i].instr == 32'h0000007F) ? 32'd1 : 32'd2) :
                          ex_misal[i] ? 32'd0 :
                          ((ex_u[i].instr[31:20] == 12'h000) ? 32'd11 : 32'd3);
        end
    end

    rv32im_alu_g u_alu_0 (
        .alu_op(ex_op[0]),
        .operand_a(ex_a[0]),
        .operand_b(ex_b[0]),
        .result(alu_res[0]),
        .zero(alu_zero[0]),
        .less_than(alu_lt[0]),
        .less_than_unsigned(alu_ltu[0])
    );

    rv32im_alu_g u_alu_1 (
        .alu_op(ex_op[1]),
        .operand_a(ex_a[1]),
        .operand_b(ex_b[1]),
        .result(alu_res[1]),
        .zero(alu_zero[1]),
        .less_than(alu_lt[1]),
        .less_than_unsigned(alu_ltu[1])
    );

    rv32im_branch_unit_g u_branch_unit_0 (
        .pc(ex_u[0].pc),
        .immediate(ex_imm[0]),
        .operand_a(ex_s1[0]),
        .operand_b(ex_s2[0]),
        .is_branch(ex_u[0].is_branch),
        .is_jal(ex_u[0].is_jal),
        .is_jalr(ex_u[0].is_jalr),
        .branch_op(ex_u[0].funct3),
        .branch_taken(bu_taken[0]),
        .redirect_valid(bu_redirect[0]),
        .branch_target(bu_target[0]),
        .link_address(bu_link[0])
    );

    rv32im_branch_unit_g u_branch_unit_1 (
        .pc(ex_u[1].pc),
        .immediate(ex_imm[1]),
        .operand_a(ex_s1[1]),
        .operand_b(ex_s2[1]),
        .is_branch(ex_u[1].is_branch),
        .is_jal(ex_u[1].is_jal),
        .is_jalr(ex_u[1].is_jalr),
        .branch_op(ex_u[1].funct3),
        .branch_taken(bu_taken[1]),
        .redirect_valid(bu_redirect[1]),
        .branch_target(bu_target[1]),
        .link_address(bu_link[1])
    );

    always_comb begin
        for (int i = 0; i < 2; i = i + 1) begin
            ex_next[i] = bu_redirect[i] ? bu_target[i] : (ex_u[i].pc + 32'd4);
            if (ex_ctl[i])
                ex_res[i] = (ex_u[i].is_jal || ex_u[i].is_jalr) ? bu_link[i] : 32'd0;
            else if (ex_sys[i])
                ex_res[i] = csr_read_data;
            else
                ex_res[i] = alu_res[i];
        end
    end

    rv32im_branch_recovery_g #(
        .ADDR_BITS(32),
        .ROB_TAG_BITS(5)
    ) u_branch_recovery_0 (
        .resolve_valid(ex_fire[0] && ex_ctl[0]),
        .resolve_rob_tag(ex_rob[0]),
        .predicted_next_pc(ex_u[0].pred_pc),
        .actual_next_pc(ex_next[0]),
        .mispredict(br_mis[0]),
        .recovery_valid(br_recov_valid[0]),
        .recovery_pc(br_rpc[0]),
        .recovery_rob_tag(br_rtag[0]),
        .flush_frontend(br_flush_fe[0]),
        .flush_decode(br_flush_dec[0]),
        .flush_rename(br_flush_ren[0]),
        .flush_issue(br_flush_iss[0])
    );

    rv32im_branch_recovery_g #(
        .ADDR_BITS(32),
        .ROB_TAG_BITS(5)
    ) u_branch_recovery_1 (
        .resolve_valid(ex_fire[1] && ex_ctl[1]),
        .resolve_rob_tag(ex_rob[1]),
        .predicted_next_pc(ex_u[1].pred_pc),
        .actual_next_pc(ex_next[1]),
        .mispredict(br_mis[1]),
        .recovery_valid(br_recov_valid[1]),
        .recovery_pc(br_rpc[1]),
        .recovery_rob_tag(br_rtag[1]),
        .flush_frontend(br_flush_fe[1]),
        .flush_decode(br_flush_dec[1]),
        .flush_rename(br_flush_ren[1]),
        .flush_issue(br_flush_iss[1])
    );

    always_comb begin
        md_cand0 = ex_v[0] && ex_md[0];
        md_cand1 = ex_v[1] && ex_md[1];
        md_req_valid = md_cand0 || md_cand1;
        md_req_f3 = md_cand0 ? ex_u[0].funct3 : ex_u[1].funct3;
        md_req_a = md_cand0 ? ex_s1[0] : ex_s1[1];
        md_req_b = md_cand0 ? ex_s2[0] : ex_s2[1];
        md_take[0] = md_cand0 && md_req_ready;
        md_take[1] = !md_cand0 && md_cand1 && md_req_ready;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            md_pdst <= '0;
            md_rob <= '0;
            md_wr <= 1'b0;
        end else if (md_take[0]) begin
            md_pdst <= ex_pdst[0];
            md_rob <= ex_rob[0];
            md_wr <= ex_wr[0];
        end else if (md_take[1]) begin
            md_pdst <= ex_pdst[1];
            md_rob <= ex_rob[1];
            md_wr <= ex_wr[1];
        end
    end

    always_comb begin
        ws_valid[0] = mem_c_valid;
        ws_valid[1] = md_rsp_valid && !flush;
        ws_valid[2] = ex_v[0] && !ex_md[0];
        ws_valid[3] = ex_v[1] && !ex_md[1];

        src_rob[0] = mem_c_rob;
        src_wr[0] = mem_c_wr;
        src_exc[0] = mem_c_exc;
        src_cause[0] = mem_c_cause;
        src_pdst[0] = mem_c_wr ? mem_c_pdst : 6'd0;
        src_data[0] = mem_c_data;

        src_rob[1] = md_rob;
        src_wr[1] = md_wr;
        src_exc[1] = 1'b0;
        src_cause[1] = 32'd0;
        src_pdst[1] = md_wr ? md_pdst : 6'd0;
        src_data[1] = md_rsp_result;

        for (int i = 0; i < 2; i = i + 1) begin
            src_rob[2 + i] = ex_rob[i];
            src_wr[2 + i] = ex_wr[i];
            src_exc[2 + i] = ex_exc[i];
            src_cause[2 + i] = ex_cause[i];
            src_pdst[2 + i] = ex_wr[i] ? ex_pdst[i] : 6'd0;
            src_data[2 + i] = ex_res[i];
        end

        for (int s = 0; s < 4; s = s + 1) begin
            ws_pdst[s*6 +: 6] = src_pdst[s];
            ws_data[s*32 +: 32] = src_data[s];
        end
    end

    rv32im_wakeup_select_g #(
        .PHYS_BITS(6),
        .DATA_BITS(32),
        .INPUTS(4),
        .OUTPUTS(2),
        .INDEX_BITS(2)
    ) u_wakeup_select (
        .in_valid(ws_valid),
        .in_pdst(ws_pdst),
        .in_data(ws_data),
        .out_valid(ws_out_valid),
        .out_pdst(ws_out_pdst),
        .out_data(ws_out_data),
        .out_index(ws_out_index)
    );

    always_comb begin
        ws_chosen = '0;
        for (int k = 0; k < 2; k = k + 1) begin
            lane_sel[k] = ws_out_index[k*2 +: 2];
            lane_v[k] = ws_out_valid[k];
            if (ws_out_valid[k])
                ws_chosen[ws_out_index[k*2 +: 2]] = 1'b1;
            lane_rob[k] = src_rob[lane_sel[k]];
            lane_wr[k] = src_wr[lane_sel[k]] && (ws_out_pdst[k*6 +: 6] != 6'd0);
            lane_exc[k] = ws_out_valid[k] && src_exc[lane_sel[k]];
            lane_cause[k] = src_cause[lane_sel[k]];
            lane_pdst[k] = ws_out_pdst[k*6 +: 6];
            lane_data[k] = ws_out_data[k*32 +: 32];
        end

        wk_valid0 = lane_v[0] && lane_wr[0];
        wk_valid1 = lane_v[1] && lane_wr[1];
        wk_pdst0 = lane_pdst[0];
        wk_pdst1 = lane_pdst[1];
        wk_data0 = lane_data[0];
        wk_data1 = lane_data[1];

        ex_sel[0] = ws_chosen[2];
        ex_sel[1] = ws_chosen[3];
        md_rsp_ready = ws_chosen[1] || flush;

        ex_ready[0] = ex_md[0] ? md_take[0] : ex_sel[0];
        ex_ready[1] = ex_md[1] ? md_take[1] : ex_sel[1];
        ex_fire[0] = ex_v[0] && ex_ready[0];
        ex_fire[1] = ex_v[1] && ex_ready[1];
        iq_issue_ready0 = ex_ready[0];
        iq_issue_ready1 = ex_ready[1];
    end

    rv32im_writeback_g #(
        .XLEN(32),
        .PHYS_REG_BITS(6),
        .ROB_TAG_BITS(5)
    ) u_writeback (
        .valid_0(lane_v[0]),
        .pdst_0(lane_pdst[0]),
        .rob_tag_0(lane_rob[0]),
        .result_0(lane_data[0]),
        .writes_rd_0(lane_wr[0]),
        .valid_1(lane_v[1]),
        .pdst_1(lane_pdst[1]),
        .rob_tag_1(lane_rob[1]),
        .result_1(lane_data[1]),
        .writes_rd_1(lane_wr[1]),
        .prf_we_0(prf_we0),
        .prf_waddr_0(prf_waddr0),
        .prf_wdata_0(prf_wdata0),
        .prf_we_1(prf_we1),
        .prf_waddr_1(prf_waddr1),
        .prf_wdata_1(prf_wdata1),
        .completion_valid_0(wb_cv0),
        .completion_rob_tag_0(wb_ctag0),
        .completion_result_0(wb_cres0),
        .completion_valid_1(wb_cv1),
        .completion_rob_tag_1(wb_ctag1),
        .completion_result_1(wb_cres1)
    );

    rv32im_completion_bus_g #(
        .XLEN(32),
        .ROB_TAG_BITS(5)
    ) u_completion_bus (
        .valid_0(wb_cv0),
        .rob_tag_0(wb_ctag0),
        .result_0(wb_cres0),
        .valid_1(wb_cv1),
        .rob_tag_1(wb_ctag1),
        .result_1(wb_cres1),
        .completion_valid_0(cb_v0),
        .completion_rob_tag_0(cb_tag0),
        .completion_result_0(cb_res0),
        .completion_valid_1(cb_v1),
        .completion_rob_tag_1(cb_tag1),
        .completion_result_1(cb_res1)
    );

    always_comb begin
        csr_read_valid = 1'b1;
        csr_read_addr = ex_csr[0] ? ex_u[0].instr[31:20] : ex_u[1].instr[31:20];
        csr_write_valid = 1'b0;
        csr_write_addr = csr_read_addr;
        csr_write_data = 32'd0;
        csr_write_cmd = 3'd0;
        if (ex_fire[0] && ex_csr[0]) begin
            csr_write_valid = !(ex_u[0].funct3[1] && (ex_u[0].instr[19:15] == 5'd0));
            csr_write_data = ex_u[0].funct3[2] ? ex_u[0].imm : ex_s1[0];
            csr_write_cmd = {1'b0, ex_u[0].funct3[1:0]};
        end else if (ex_fire[1] && ex_csr[1]) begin
            csr_write_valid = !(ex_u[1].funct3[1] && (ex_u[1].instr[19:15] == 5'd0));
            csr_write_data = ex_u[1].funct3[2] ? ex_u[1].imm : ex_s1[1];
            csr_write_cmd = {1'b0, ex_u[1].funct3[1:0]};
        end
    end

    always_comb begin
        f0v = ex_fire[0] && ex_ctl[0] && !ex_misal[0];
        f1v = ex_fire[1] && ex_ctl[1] && !ex_misal[1];
        pr_update_valid = 1'b0;
        pr_update_pc = 32'd0;
        pr_update_hist = 4'd0;
        pr_update_taken = 1'b0;
        pr_update_target = 32'd0;
        pu_nv = 1'b0;
        pu_npc = 32'd0;
        pu_nhist = 4'd0;
        pu_ntaken = 1'b0;
        pu_ntgt = 32'd0;
        if (pu_v) begin
            pr_update_valid = 1'b1;
            pr_update_pc = pu_pc;
            pr_update_hist = pu_hist;
            pr_update_taken = pu_taken;
            pr_update_target = pu_tgt;
            if (f0v) begin
                pu_nv = 1'b1; pu_npc = ex_u[0].pc; pu_nhist = ex_u[0].ghist;
                pu_ntaken = bu_redirect[0]; pu_ntgt = bu_target[0];
            end else if (f1v) begin
                pu_nv = 1'b1; pu_npc = ex_u[1].pc; pu_nhist = ex_u[1].ghist;
                pu_ntaken = bu_redirect[1]; pu_ntgt = bu_target[1];
            end
        end else if (f0v) begin
            pr_update_valid = 1'b1;
            pr_update_pc = ex_u[0].pc;
            pr_update_hist = ex_u[0].ghist;
            pr_update_taken = bu_redirect[0];
            pr_update_target = bu_target[0];
            if (f1v) begin
                pu_nv = 1'b1; pu_npc = ex_u[1].pc; pu_nhist = ex_u[1].ghist;
                pu_ntaken = bu_redirect[1]; pu_ntgt = bu_target[1];
            end
        end else if (f1v) begin
            pr_update_valid = 1'b1;
            pr_update_pc = ex_u[1].pc;
            pr_update_hist = ex_u[1].ghist;
            pr_update_taken = bu_redirect[1];
            pr_update_target = bu_target[1];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pu_v <= 1'b0;
            pu_pc <= 32'd0;
            pu_hist <= 4'd0;
            pu_taken <= 1'b0;
            pu_tgt <= 32'd0;
        end else begin
            pu_v <= pu_nv;
            pu_pc <= pu_npc;
            pu_hist <= pu_nhist;
            pu_taken <= pu_ntaken;
            pu_tgt <= pu_ntgt;
        end
    end

    uop_t tbl_ex_s0;
    uop_t tbl_ex_s1;
    assign tbl_ex_s0 = tbl_ex_data0;
    assign tbl_ex_s1 = tbl_ex_data1;

endmodule