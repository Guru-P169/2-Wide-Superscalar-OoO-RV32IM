module rv32im_ooo_core_g (
    input  logic        clk,
    input  logic        rst_n,
    output logic        i_req_valid,
    input  logic        i_req_ready,
    output logic [31:0] i_req_addr,
    input  logic        i_resp_valid,
    output logic        i_resp_ready,
    input  logic [63:0] i_resp_data,
    input  logic [1:0]  i_resp_error,
    output logic        d_req_valid,
    input  logic        d_req_ready,
    output logic        d_req_write,
    output logic [31:0] d_req_addr,
    output logic [31:0] d_req_wdata,
    output logic [1:0]  d_req_size,
    input  logic        d_resp_valid,
    output logic        d_resp_ready,
    input  logic [31:0] d_resp_rdata,
    input  logic        d_resp_error,
    output logic        i_invalidate,
    output logic        core_busy,
    output logic        core_halted,
    output logic        exception_valid,
    output logic [31:0] exception_pc
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

    localparam int UW = $bits(uop_t);

    logic          flush;
    logic [2:0]    rasc_ptr;
    logic [3:0]    rasc_count;
    logic [255:0]  rasc_stack;
    logic [3:0]    ghr_fix_q;
    logic [31:0]   flush_pc;
    logic          pr_update_valid;
    logic [31:0]   pr_update_pc;
    logic [3:0]    pr_update_hist;
    logic          pr_update_taken;
    logic [31:0]   pr_update_target;
    logic          q_out_valid0;
    logic          q_out_valid1;
    logic [31:0]   q_out_pc0;
    logic [31:0]   q_out_pc1;
    logic [31:0]   q_out_inst0;
    logic [31:0]   q_out_inst1;
    logic          q_out_pt0;
    logic          q_out_pt1;
    logic [31:0]   q_out_tgt0;
    logic [31:0]   q_out_tgt1;
    logic [3:0]    q_out_hist0;
    logic [3:0]    q_out_hist1;
    logic          q_out_ready0;
    logic          q_out_ready1;
    logic          ld0;
    logic          ld1;
    logic          st0;
    logic          st1;
    logic [191:0]  restore_map;
    logic [63:0]   restore_bm;
    logic          disp_rob_valid0;
    logic          disp_rob_valid1;
    logic [UW-1:0] disp_rob_uop0;
    logic [UW-1:0] disp_rob_uop1;
    logic          disp_intq_valid0;
    logic          disp_intq_valid1;
    logic [UW-1:0] disp_intq_uop0;
    logic [UW-1:0] disp_intq_uop1;
    logic          disp_memq_valid0;
    logic          disp_memq_valid1;
    logic [UW-1:0] disp_memq_uop0;
    logic [UW-1:0] disp_memq_uop1;
    logic          disp_fire0;
    logic          disp_fire1;
    logic [4:0]    rob_idx0;
    logic [4:0]    rob_idx1;
    logic [5:0]    rob_occ;
    logic          rob_empty;
    logic          rob_cv0;
    logic [4:0]    rob_cidx0;
    logic [4:0]    rob_cidx1;
    logic          iq_issue_valid0;
    logic          iq_issue_valid1;
    logic          iq_issue_ready0;
    logic          iq_issue_ready1;
    logic [4:0]    iq_op0;
    logic [4:0]    iq_op1;
    logic [5:0]    iq_pdst0;
    logic [5:0]    iq_pdst1;
    logic [31:0]   iq_src1_0;
    logic [31:0]   iq_src1_1;
    logic [31:0]   iq_src2_0;
    logic [31:0]   iq_src2_1;
    logic [31:0]   iq_imm0;
    logic [31:0]   iq_imm1;
    logic [4:0]    iq_rob0;
    logic [4:0]    iq_rob1;
    logic [3:0]    iq_occ;
    logic          mq_issue_valid0;
    logic          mq_issue_valid1;
    logic          mq_issue_ready0;
    logic          mq_issue_ready1;
    logic          mq_is_load0;
    logic          mq_is_load1;
    logic          mq_is_store0;
    logic          mq_is_store1;
    logic [1:0]    mq_size0;
    logic [1:0]    mq_size1;
    logic [31:0]   mq_base0;
    logic [31:0]   mq_base1;
    logic [31:0]   mq_sdata0;
    logic [31:0]   mq_sdata1;
    logic [31:0]   mq_imm0;
    logic [31:0]   mq_imm1;
    logic [4:0]    mq_rob0;
    logic [4:0]    mq_rob1;
    logic [3:0]    mq_occ;
    logic [1:0]    ex_ctl;
    logic [1:0]    ex_fire;
    logic [1:0]    br_mis;
    logic [9:0]    ex_rob_flat;
    logic [63:0]   br_rpc_flat;
    logic          md_req_valid;
    logic          md_req_ready;
    logic [2:0]    md_req_f3;
    logic [31:0]   md_req_a;
    logic [31:0]   md_req_b;
    logic          md_rsp_valid;
    logic          md_rsp_ready;
    logic [31:0]   md_rsp_result;
    logic          mem_c_valid;
    logic [5:0]    mem_c_pdst;
    logic [31:0]   mem_c_data;
    logic [4:0]    mem_c_rob;
    logic          mem_c_wr;
    logic          mem_c_exc;
    logic [31:0]   mem_c_cause;
    logic [4:0]    lq_count;
    logic [4:0]    sq_count;
    logic [1:0]    lane_exc;
    logic [63:0]   lane_cause_flat;
    logic          wk_valid0;
    logic          wk_valid1;
    logic [5:0]    wk_pdst0;
    logic [5:0]    wk_pdst1;
    logic [31:0]   wk_data0;
    logic [31:0]   wk_data1;
    logic          prf_we0;
    logic          prf_we1;
    logic [5:0]    prf_waddr0;
    logic [5:0]    prf_waddr1;
    logic [31:0]   prf_wdata0;
    logic [31:0]   prf_wdata1;
    logic          cb_v0;
    logic          cb_v1;
    logic [4:0]    cb_tag0;
    logic [4:0]    cb_tag1;
    logic [31:0]   cb_res0;
    logic [31:0]   cb_res1;
    logic          csr_read_valid;
    logic [11:0]   csr_read_addr;
    logic [31:0]   csr_read_data;
    logic          csr_write_valid;
    logic [11:0]   csr_write_addr;
    logic [31:0]   csr_write_data;
    logic [2:0]    csr_write_cmd;
    logic          rc_recovery_valid;
    logic [31:0]   rc_recovery_pc;
    logic          cs_free_valid0;
    logic [5:0]    cs_free_preg0;
    logic          cs_free_valid1;
    logic [5:0]    cs_free_preg1;
    logic          cs_ret_valid0;
    logic [4:0]    cs_ret_idx0;
    logic          cs_ret_valid1;
    logic [4:0]    cs_ret_idx1;
    logic [4:0]    ld_tag5;
    logic [UW-1:0] tbl_ex_data0;
    logic [UW-1:0] tbl_ex_data1;
    logic [UW-1:0] tbl_cm_data0;
    logic [UW-1:0] tbl_cm_data1;
    logic [UW-1:0] tbl_ld_data;
    logic [31:0]   tbl_is_load_vec;
    logic [31:0]   tbl_is_store_vec;

    rv32im_frontend_pc_bpu_fq_g u_frontend_pc_bpu_fq (
        .clk             (clk),
        .rst_n           (rst_n),
        .i_req_ready     (i_req_ready),
        .i_resp_valid    (i_resp_valid),
        .i_resp_data     (i_resp_data),
        .i_resp_error    (i_resp_error),
        .flush           (flush),
        .rasc_ptr        (rasc_ptr),
        .rasc_count      (rasc_count),
        .rasc_stack      (rasc_stack),
        .ghr_fix_q       (ghr_fix_q),
        .flush_pc        (flush_pc),
        .pr_update_valid (pr_update_valid),
        .pr_update_pc    (pr_update_pc),
        .pr_update_hist  (pr_update_hist),
        .pr_update_taken (pr_update_taken),
        .pr_update_target(pr_update_target),
        .q_out_ready0    (q_out_ready0),
        .q_out_ready1    (q_out_ready1),
        .i_req_valid     (i_req_valid),
        .i_req_addr      (i_req_addr),
        .i_resp_ready    (i_resp_ready),
        .q_out_valid0    (q_out_valid0),
        .q_out_valid1    (q_out_valid1),
        .q_out_pc0       (q_out_pc0),
        .q_out_pc1       (q_out_pc1),
        .q_out_inst0     (q_out_inst0),
        .q_out_inst1     (q_out_inst1),
        .q_out_pt0       (q_out_pt0),
        .q_out_pt1       (q_out_pt1),
        .q_out_tgt0      (q_out_tgt0),
        .q_out_tgt1      (q_out_tgt1),
        .q_out_hist0     (q_out_hist0),
        .q_out_hist1     (q_out_hist1)
    );

    rv32im_rename_dispatch_dec_ren_prf_g #(
        .UW(UW)
    ) u_rename_dispatch_dec_ren_prf (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (flush),
        .q_out_valid0    (q_out_valid0),
        .q_out_valid1    (q_out_valid1),
        .q_out_pc0       (q_out_pc0),
        .q_out_pc1       (q_out_pc1),
        .q_out_inst0     (q_out_inst0),
        .q_out_inst1     (q_out_inst1),
        .q_out_pt0       (q_out_pt0),
        .q_out_pt1       (q_out_pt1),
        .q_out_tgt0      (q_out_tgt0),
        .q_out_tgt1      (q_out_tgt1),
        .q_out_hist0     (q_out_hist0),
        .q_out_hist1     (q_out_hist1),
        .restore_map     (restore_map),
        .restore_bm      (restore_bm),
        .rob_occ         (rob_occ),
        .rob_empty       (rob_empty),
        .iq_occ          (iq_occ),
        .mq_occ          (mq_occ),
        .lq_count        (lq_count),
        .sq_count        (sq_count),
        .wk_valid0       (wk_valid0),
        .wk_valid1       (wk_valid1),
        .wk_pdst0        (wk_pdst0),
        .wk_pdst1        (wk_pdst1),
        .wk_data0        (wk_data0),
        .wk_data1        (wk_data1),
        .prf_we0         (prf_we0),
        .prf_we1         (prf_we1),
        .prf_waddr0      (prf_waddr0),
        .prf_waddr1      (prf_waddr1),
        .prf_wdata0      (prf_wdata0),
        .prf_wdata1      (prf_wdata1),
        .cs_free_valid0  (cs_free_valid0),
        .cs_free_preg0   (cs_free_preg0),
        .cs_free_valid1  (cs_free_valid1),
        .cs_free_preg1   (cs_free_preg1),
        .q_out_ready0    (q_out_ready0),
        .q_out_ready1    (q_out_ready1),
        .ld0             (ld0),
        .ld1             (ld1),
        .st0             (st0),
        .st1             (st1),
        .disp_rob_valid0 (disp_rob_valid0),
        .disp_rob_valid1 (disp_rob_valid1),
        .disp_rob_uop0   (disp_rob_uop0),
        .disp_rob_uop1   (disp_rob_uop1),
        .disp_intq_valid0(disp_intq_valid0),
        .disp_intq_valid1(disp_intq_valid1),
        .disp_intq_uop0  (disp_intq_uop0),
        .disp_intq_uop1  (disp_intq_uop1),
        .disp_memq_valid0(disp_memq_valid0),
        .disp_memq_valid1(disp_memq_valid1),
        .disp_memq_uop0  (disp_memq_uop0),
        .disp_memq_uop1  (disp_memq_uop1),
        .disp_fire0      (disp_fire0),
        .disp_fire1      (disp_fire1)
    );

    rv32im_issue_intq_memq_g #(
        .UW(UW)
    ) u_issue_intq_memq (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (flush),
        .disp_intq_valid0(disp_intq_valid0),
        .disp_intq_valid1(disp_intq_valid1),
        .disp_intq_uop0  (disp_intq_uop0),
        .disp_intq_uop1  (disp_intq_uop1),
        .disp_memq_valid0(disp_memq_valid0),
        .disp_memq_valid1(disp_memq_valid1),
        .disp_memq_uop0  (disp_memq_uop0),
        .disp_memq_uop1  (disp_memq_uop1),
        .rob_idx0        (rob_idx0),
        .rob_idx1        (rob_idx1),
        .iq_issue_ready0 (iq_issue_ready0),
        .iq_issue_ready1 (iq_issue_ready1),
        .mq_issue_ready0 (mq_issue_ready0),
        .mq_issue_ready1 (mq_issue_ready1),
        .wk_valid0       (wk_valid0),
        .wk_valid1       (wk_valid1),
        .wk_pdst0        (wk_pdst0),
        .wk_pdst1        (wk_pdst1),
        .wk_data0        (wk_data0),
        .wk_data1        (wk_data1),
        .iq_issue_valid0 (iq_issue_valid0),
        .iq_issue_valid1 (iq_issue_valid1),
        .iq_op0          (iq_op0),
        .iq_op1          (iq_op1),
        .iq_pdst0        (iq_pdst0),
        .iq_pdst1        (iq_pdst1),
        .iq_src1_0       (iq_src1_0),
        .iq_src1_1       (iq_src1_1),
        .iq_src2_0       (iq_src2_0),
        .iq_src2_1       (iq_src2_1),
        .iq_imm0         (iq_imm0),
        .iq_imm1         (iq_imm1),
        .iq_rob0         (iq_rob0),
        .iq_rob1         (iq_rob1),
        .iq_occ          (iq_occ),
        .mq_issue_valid0 (mq_issue_valid0),
        .mq_issue_valid1 (mq_issue_valid1),
        .mq_is_load0     (mq_is_load0),
        .mq_is_load1     (mq_is_load1),
        .mq_is_store0    (mq_is_store0),
        .mq_is_store1    (mq_is_store1),
        .mq_size0        (mq_size0),
        .mq_size1        (mq_size1),
        .mq_base0        (mq_base0),
        .mq_base1        (mq_base1),
        .mq_sdata0       (mq_sdata0),
        .mq_sdata1       (mq_sdata1),
        .mq_imm0         (mq_imm0),
        .mq_imm1         (mq_imm1),
        .mq_rob0         (mq_rob0),
        .mq_rob1         (mq_rob1),
        .mq_occ          (mq_occ)
    );

    rv32im_exec_alu_bru_wb_g #(
        .UW(UW)
    ) u_exec_alu_bru_wb (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (flush),
        .iq_issue_valid0 (iq_issue_valid0),
        .iq_issue_valid1 (iq_issue_valid1),
        .iq_op0          (iq_op0),
        .iq_op1          (iq_op1),
        .iq_pdst0        (iq_pdst0),
        .iq_pdst1        (iq_pdst1),
        .iq_src1_0       (iq_src1_0),
        .iq_src1_1       (iq_src1_1),
        .iq_src2_0       (iq_src2_0),
        .iq_src2_1       (iq_src2_1),
        .iq_imm0         (iq_imm0),
        .iq_imm1         (iq_imm1),
        .iq_rob0         (iq_rob0),
        .iq_rob1         (iq_rob1),
        .md_req_ready    (md_req_ready),
        .md_rsp_valid    (md_rsp_valid),
        .md_rsp_result   (md_rsp_result),
        .mem_c_valid     (mem_c_valid),
        .mem_c_pdst      (mem_c_pdst),
        .mem_c_data      (mem_c_data),
        .mem_c_rob       (mem_c_rob),
        .mem_c_wr        (mem_c_wr),
        .mem_c_exc       (mem_c_exc),
        .mem_c_cause     (mem_c_cause),
        .csr_read_data   (csr_read_data),
        .tbl_ex_data0    (tbl_ex_data0),
        .tbl_ex_data1    (tbl_ex_data1),
        .pr_update_valid (pr_update_valid),
        .pr_update_pc    (pr_update_pc),
        .pr_update_hist  (pr_update_hist),
        .pr_update_taken (pr_update_taken),
        .pr_update_target(pr_update_target),
        .iq_issue_ready0 (iq_issue_ready0),
        .iq_issue_ready1 (iq_issue_ready1),
        .ex_ctl          (ex_ctl),
        .ex_fire         (ex_fire),
        .br_mis          (br_mis),
        .ex_rob_flat     (ex_rob_flat),
        .br_rpc_flat     (br_rpc_flat),
        .md_req_valid    (md_req_valid),
        .md_req_f3       (md_req_f3),
        .md_req_a        (md_req_a),
        .md_req_b        (md_req_b),
        .md_rsp_ready    (md_rsp_ready),
        .lane_exc        (lane_exc),
        .lane_cause_flat (lane_cause_flat),
        .wk_valid0       (wk_valid0),
        .wk_valid1       (wk_valid1),
        .wk_pdst0        (wk_pdst0),
        .wk_pdst1        (wk_pdst1),
        .wk_data0        (wk_data0),
        .wk_data1        (wk_data1),
        .prf_we0         (prf_we0),
        .prf_we1         (prf_we1),
        .prf_waddr0      (prf_waddr0),
        .prf_waddr1      (prf_waddr1),
        .prf_wdata0      (prf_wdata0),
        .prf_wdata1      (prf_wdata1),
        .cb_v0           (cb_v0),
        .cb_v1           (cb_v1),
        .cb_tag0         (cb_tag0),
        .cb_tag1         (cb_tag1),
        .cb_res0         (cb_res0),
        .cb_res1         (cb_res1),
        .csr_read_valid  (csr_read_valid),
        .csr_read_addr   (csr_read_addr),
        .csr_write_valid (csr_write_valid),
        .csr_write_addr  (csr_write_addr),
        .csr_write_data  (csr_write_data),
        .csr_write_cmd   (csr_write_cmd)
    );

    rv32im_rob_commit_csr_rec_g #(
        .UW(UW)
    ) u_rob_commit_csr_rec (
        .clk              (clk),
        .rst_n            (rst_n),
        .flush            (flush),
        .disp_rob_valid0  (disp_rob_valid0),
        .disp_rob_valid1  (disp_rob_valid1),
        .disp_rob_uop0    (disp_rob_uop0),
        .disp_rob_uop1    (disp_rob_uop1),
        .ex_ctl           (ex_ctl),
        .ex_fire          (ex_fire),
        .br_mis           (br_mis),
        .ex_rob_flat      (ex_rob_flat),
        .br_rpc_flat      (br_rpc_flat),
        .lane_exc         (lane_exc),
        .lane_cause_flat  (lane_cause_flat),
        .cb_v0            (cb_v0),
        .cb_v1            (cb_v1),
        .cb_tag0          (cb_tag0),
        .cb_tag1          (cb_tag1),
        .cb_res0          (cb_res0),
        .cb_res1          (cb_res1),
        .csr_read_valid   (csr_read_valid),
        .csr_read_addr    (csr_read_addr),
        .csr_write_valid  (csr_write_valid),
        .csr_write_addr   (csr_write_addr),
        .csr_write_data   (csr_write_data),
        .csr_write_cmd    (csr_write_cmd),
        .tbl_cm_data0     (tbl_cm_data0),
        .tbl_cm_data1     (tbl_cm_data1),
        .i_invalidate     (i_invalidate),
        .core_busy        (core_busy),
        .core_halted      (core_halted),
        .exception_valid  (exception_valid),
        .exception_pc     (exception_pc),
        .rasc_ptr         (rasc_ptr),
        .rasc_count       (rasc_count),
        .rasc_stack       (rasc_stack),
        .ghr_fix_q        (ghr_fix_q),
        .restore_map      (restore_map),
        .restore_bm       (restore_bm),
        .rob_idx0         (rob_idx0),
        .rob_idx1         (rob_idx1),
        .rob_occ          (rob_occ),
        .rob_empty        (rob_empty),
        .rob_cv0          (rob_cv0),
        .rob_cidx0        (rob_cidx0),
        .rob_cidx1        (rob_cidx1),
        .csr_read_data    (csr_read_data),
        .rc_recovery_valid(rc_recovery_valid),
        .rc_recovery_pc   (rc_recovery_pc),
        .cs_free_valid0   (cs_free_valid0),
        .cs_free_preg0    (cs_free_preg0),
        .cs_free_valid1   (cs_free_valid1),
        .cs_free_preg1    (cs_free_preg1),
        .cs_ret_valid0    (cs_ret_valid0),
        .cs_ret_idx0      (cs_ret_idx0),
        .cs_ret_valid1    (cs_ret_valid1),
        .cs_ret_idx1      (cs_ret_idx1)
    );

    rv32im_lsu_lsq_fsm_g #(
        .UW(UW)
    ) u_lsu_lsq_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        .d_req_ready     (d_req_ready),
        .d_resp_valid    (d_resp_valid),
        .d_resp_rdata    (d_resp_rdata),
        .d_resp_error    (d_resp_error),
        .flush           (flush),
        .ld0             (ld0),
        .ld1             (ld1),
        .st0             (st0),
        .st1             (st1),
        .disp_rob_valid0 (disp_rob_valid0),
        .disp_rob_valid1 (disp_rob_valid1),
        .disp_fire0      (disp_fire0),
        .disp_fire1      (disp_fire1),
        .rob_idx0        (rob_idx0),
        .rob_idx1        (rob_idx1),
        .rob_occ         (rob_occ),
        .rob_empty       (rob_empty),
        .rob_cv0         (rob_cv0),
        .rob_cidx0       (rob_cidx0),
        .mq_issue_valid0 (mq_issue_valid0),
        .mq_issue_valid1 (mq_issue_valid1),
        .mq_is_load0     (mq_is_load0),
        .mq_is_load1     (mq_is_load1),
        .mq_is_store0    (mq_is_store0),
        .mq_is_store1    (mq_is_store1),
        .mq_size0        (mq_size0),
        .mq_size1        (mq_size1),
        .mq_base0        (mq_base0),
        .mq_base1        (mq_base1),
        .mq_sdata0       (mq_sdata0),
        .mq_sdata1       (mq_sdata1),
        .mq_imm0         (mq_imm0),
        .mq_imm1         (mq_imm1),
        .mq_rob0         (mq_rob0),
        .mq_rob1         (mq_rob1),
        .cs_ret_valid0   (cs_ret_valid0),
        .cs_ret_idx0     (cs_ret_idx0),
        .cs_ret_valid1   (cs_ret_valid1),
        .cs_ret_idx1     (cs_ret_idx1),
        .tbl_cm_data0    (tbl_cm_data0),
        .tbl_cm_data1    (tbl_cm_data1),
        .tbl_ld_data     (tbl_ld_data),
        .tbl_is_load_vec (tbl_is_load_vec),
        .tbl_is_store_vec(tbl_is_store_vec),
        .d_req_valid     (d_req_valid),
        .d_req_write     (d_req_write),
        .d_req_addr      (d_req_addr),
        .d_req_wdata     (d_req_wdata),
        .d_req_size      (d_req_size),
        .d_resp_ready    (d_resp_ready),
        .mq_issue_ready0 (mq_issue_ready0),
        .mq_issue_ready1 (mq_issue_ready1),
        .mem_c_valid     (mem_c_valid),
        .mem_c_pdst      (mem_c_pdst),
        .mem_c_data      (mem_c_data),
        .mem_c_rob       (mem_c_rob),
        .mem_c_wr        (mem_c_wr),
        .mem_c_exc       (mem_c_exc),
        .mem_c_cause     (mem_c_cause),
        .lq_count        (lq_count),
        .sq_count        (sq_count),
        .ld_tag5         (ld_tag5)
    );

    assign flush = rc_recovery_valid;
    assign flush_pc = rc_recovery_pc;

    rv32im_muldiv_unit_g u_muldiv_unit (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(md_req_valid),
        .req_ready(md_req_ready),
        .req_funct3(md_req_f3),
        .req_operand_a(md_req_a),
        .req_operand_b(md_req_b),
        .rsp_valid(md_rsp_valid),
        .rsp_ready(md_rsp_ready),
        .rsp_result(md_rsp_result)
    );

    rv32im_uop_tbl_g #(
        .UW(UW)
    ) u_uop_tbl (
        .clk(clk),
        .rst_n(rst_n),
        .wr_valid0(disp_rob_valid0),
        .wr_idx0(rob_idx0),
        .wr_data0(disp_rob_uop0),
        .wr_valid1(disp_rob_valid1),
        .wr_idx1(rob_idx1),
        .wr_data1(disp_rob_uop1),
        .rd_ex_idx0(iq_rob0),
        .rd_ex_data0(tbl_ex_data0),
        .rd_ex_idx1(iq_rob1),
        .rd_ex_data1(tbl_ex_data1),
        .rd_cm_idx0(rob_cidx0),
        .rd_cm_data0(tbl_cm_data0),
        .rd_cm_idx1(rob_cidx1),
        .rd_cm_data1(tbl_cm_data1),
        .rd_ld_idx(ld_tag5),
        .rd_ld_data(tbl_ld_data),
        .is_load_vec(tbl_is_load_vec),
        .is_store_vec(tbl_is_store_vec)
    );

endmodule