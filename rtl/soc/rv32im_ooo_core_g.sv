module rv32im_ooo_core_g (
    input logic clk,
    input logic rst_n,

    output logic i_req_valid,
    input logic i_req_ready,
    output logic [31:0] i_req_addr,
    input logic i_resp_valid,
    output logic i_resp_ready,
    input logic [63:0] i_resp_data,
    input logic [1:0] i_resp_error,

    output logic d_req_valid,
    input logic d_req_ready,
    output logic d_req_write,
    output logic [31:0] d_req_addr,
    output logic [31:0] d_req_wdata,
    output logic [1:0] d_req_size,
    input logic d_resp_valid,
    output logic d_resp_ready,
    input logic [31:0] d_resp_rdata,
    input logic d_resp_error,

    output logic i_invalidate,

    output logic core_busy,
    output logic core_halted,
    output logic exception_valid,
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

    localparam logic [2:0] A_IDLE = 3'd0;
    localparam logic [2:0] A_REQ0 = 3'd1;
    localparam logic [2:0] A_WAIT0 = 3'd2;
    localparam logic [2:0] A_REQ1 = 3'd3;
    localparam logic [2:0] A_WAIT1 = 3'd4;
    localparam logic [2:0] A_DONE = 3'd5;
    localparam logic [2:0] A_DRAIN = 3'd6;

    localparam logic [2:0] M_IDLE = 3'd0;
    localparam logic [2:0] M_REQ = 3'd1;
    localparam logic [2:0] M_WAIT = 3'd2;
    localparam logic [2:0] M_LDRES = 3'd3;
    localparam logic [2:0] M_EXC = 3'd4;

    function automatic logic is_return_inst(input logic [31:0] ins);
        is_return_inst = (ins[6:0] == 7'b1100111) &&
                         (ins[11:7] == 5'd0) &&
                         (ins[19:15] == 5'd1 || ins[19:15] == 5'd5);
    endfunction

    logic flush;
    logic        rasc_push_valid;
    logic [31:0] rasc_push_addr;
    logic        rasc_pop_valid;
    logic [2:0]   rasc_ptr;
    logic [3:0]   rasc_count;
    logic [255:0] rasc_stack;
    logic [3:0]   ghr_fix_q;
    logic [31:0] flush_pc;

    logic fe_redirect_valid;
    logic [31:0] fe_redirect_pc;
    logic fs_req_valid;
    logic fs_req_ready;
    logic [31:0] fs_req_addr;
    logic fs_resp_valid;
    logic fs_resp_ready;
    logic [63:0] fs_resp_data;
    logic fs_valid0;
    logic fs_valid1;
    logic fs_ready0;
    logic fs_ready1;
    logic [31:0] fs_pc0;
    logic [31:0] fs_pc1;
    logic [31:0] fs_inst0;
    logic [31:0] fs_inst1;

    logic [2:0] astate;
    logic [31:0] a_base;
    logic [31:0] a_w0;
    logic [31:0] a_w1;
    logic abort;

    logic skip0;
    logic fq_room;
    logic consume_pkt;
    logic pred_redirect_valid;
    logic [31:0] pred_redirect_pc;

    logic pr_valid0;
    logic pr_valid1;
    logic pr_taken0;
    logic pr_taken1;
    logic [31:0] pr_target0;
    logic [31:0] pr_target1;
    logic [3:0] pr_hist0;
    logic [3:0] pr_hist1;
    logic pr_accept0;
    logic pr_accept1;
    logic pt0;
    logic pt1;
    logic pr_update_valid;
    logic [31:0] pr_update_pc;
    logic [3:0] pr_update_hist;
    logic pr_update_taken;
    logic [31:0] pr_update_target;
    logic ras_op0_push;
    logic ras_op0_pop;
    logic ras_op1_push;
    logic ras_op1_pop;
    logic ras_push_valid;
    logic [31:0] ras_push_addr;
    logic ras_pop_valid;

    logic q_in_valid0;
    logic q_in_valid1;
    logic [31:0] q_in_pc0;
    logic [31:0] q_in_pc1;
    logic [31:0] q_in_inst0;
    logic [31:0] q_in_inst1;
    logic q_in_pt0;
    logic q_in_pt1;
    logic [31:0] q_in_tgt0;
    logic [31:0] q_in_tgt1;
    logic [3:0] q_in_hist0;
    logic [3:0] q_in_hist1;
    logic q_in_ready0;
    logic q_in_ready1;
    logic q_out_valid0;
    logic q_out_valid1;
    logic [31:0] q_out_pc0;
    logic [31:0] q_out_pc1;
    logic [31:0] q_out_inst0;
    logic [31:0] q_out_inst1;
    logic q_out_pt0;
    logic q_out_pt1;
    logic [31:0] q_out_tgt0;
    logic [31:0] q_out_tgt1;
    logic [3:0] q_out_hist0;
    logic [3:0] q_out_hist1;
    logic q_out_ready0;
    logic q_out_ready1;
    logic [3:0] q_count;

    logic dc_in_ready0;
    logic dc_in_ready1;
    logic dc_valid0;
    logic dc_valid1;
    logic [31:0] dc_inst0;
    logic [31:0] dc_inst1;
    logic [31:0] dc_pc0;
    logic [31:0] dc_pc1;
    logic [31:0] dc_ppc0;
    logic [31:0] dc_ppc1;
    logic dc_illegal0;
    logic dc_illegal1;
    logic [6:0] dc_opcode0;
    logic [6:0] dc_opcode1;
    logic [2:0] dc_f3_0;
    logic [2:0] dc_f3_1;
    logic [6:0] dc_f7_0;
    logic [6:0] dc_f7_1;
    logic [4:0] dc_rs1_0;
    logic [4:0] dc_rs1_1;
    logic [4:0] dc_rs2_0;
    logic [4:0] dc_rs2_1;
    logic [4:0] dc_rd0;
    logic [4:0] dc_rd1;
    logic dc_urs1_0;
    logic dc_urs1_1;
    logic dc_urs2_0;
    logic dc_urs2_1;
    logic dc_wr0;
    logic dc_wr1;
    logic [31:0] dc_imm0;
    logic [31:0] dc_imm1;
    logic [4:0] dc_aluop0;
    logic [4:0] dc_aluop1;
    logic [2:0] dc_brop0;
    logic [2:0] dc_brop1;
    logic [1:0] dc_msize0;
    logic [1:0] dc_msize1;
    logic dc_lu0;
    logic dc_lu1;
    logic dc_br0;
    logic dc_br1;
    logic dc_jal0;
    logic dc_jal1;
    logic dc_jalr0;
    logic dc_jalr1;
    logic dc_ld0;
    logic dc_ld1;
    logic dc_st0;
    logic dc_st1;
    logic dc_md0;
    logic dc_md1;
    logic dc_sys0;
    logic dc_sys1;
    logic dc_fence0;
    logic dc_fence1;

    logic csr0;
    logic csr1;
    logic gate0;
    logic gate1;
    logic d_valid0;
    logic d_valid1;
    logic wr_eff0;
    logic wr_eff1;
    logic mem0;
    logic mem1;
    logic ld0;
    logic ld1;
    logic st0;
    logic st1;

    logic ren_in_ready0;
    logic ren_in_ready1;
    logic ren_out_valid0;
    logic ren_out_valid1;
    logic [5:0] ren_rs1_0;
    logic [5:0] ren_rs2_0;
    logic [5:0] ren_rd0;
    logic [5:0] ren_old0;
    logic [5:0] ren_rs1_1;
    logic [5:0] ren_rs2_1;
    logic [5:0] ren_rd1;
    logic [5:0] ren_old1;
    logic [191:0] ren_ckpt_map;
    logic [63:0] ren_free_bitmap;
    logic [191:0] restore_map;
    logic [63:0] restore_bm;
    logic [5:0] cmap [0:31];

    logic [31:0] prf_rd0;
    logic [31:0] prf_rd1;
    logic [31:0] prf_rd2;
    logic [31:0] prf_rd3;
    logic [63:0] sb_ready;

    logic byp0_r1;
    logic [31:0] byp0_d1;
    logic byp0_r2;
    logic [31:0] byp0_d2;
    logic byp1_r1;
    logic [31:0] byp1_d1;
    logic byp1_r2;
    logic [31:0] byp1_d2;

    uop_t u0;
    uop_t u1;
    logic [UW-1:0] disp_in_uop0;
    logic [UW-1:0] disp_in_uop1;
    logic disp_in_ready0;
    logic disp_in_ready1;
    logic [5:0] rob_free_count;
    logic [3:0] intq_free_count;
    logic [3:0] memq_free_count;
    logic disp_rob_valid0;
    logic disp_rob_valid1;
    logic [UW-1:0] disp_rob_uop0;
    logic [UW-1:0] disp_rob_uop1;
    logic disp_intq_valid0;
    logic disp_intq_valid1;
    logic [UW-1:0] disp_intq_uop0;
    logic [UW-1:0] disp_intq_uop1;
    logic disp_memq_valid0;
    logic disp_memq_valid1;
    logic [UW-1:0] disp_memq_uop0;
    logic [UW-1:0] disp_memq_uop1;
    logic disp_fire0;
    logic disp_fire1;
    uop_t rob_u0;
    uop_t rob_u1;
    uop_t intq_u0;
    uop_t intq_u1;
    uop_t memq_u0;
    uop_t memq_u1;

    uop_t uop_tbl [0:31];
    logic [31:0] mis_valid;
    logic [31:0] mis_pc [0:31];

    logic [4:0] rob_idx0;
    logic [4:0] rob_idx1;
    logic [5:0] rob_occ;
    logic rob_empty;
    logic rob_full;
    logic rob_cv0;
    logic rob_cv1;
    logic rob_cr0;
    logic rob_cr1;
    logic [4:0] rob_cidx0;
    logic [4:0] rob_cidx1;
    logic [31:0] rob_cpc0;
    logic [31:0] rob_cpc1;
    logic [4:0] rob_crd0;
    logic [4:0] rob_crd1;
    logic [5:0] rob_cpdst0;
    logic [5:0] rob_cpdst1;
    logic [5:0] rob_cold0;
    logic [5:0] rob_cold1;
    logic [31:0] rob_cdata0;
    logic [31:0] rob_cdata1;
    logic rob_cwr0;
    logic rob_cwr1;
    logic rob_cexc0;
    logic rob_cexc1;
    logic [31:0] rob_ccause0;
    logic [31:0] rob_ccause1;

    logic iq_enq_valid0;
    logic iq_enq_valid1;
    logic iq_enq_ready0;
    logic iq_enq_ready1;
    uop_t iq_enq_u0;
    uop_t iq_enq_u1;
    logic [4:0] iq_enq_rob0;
    logic [4:0] iq_enq_rob1;
    logic iq_issue_valid0;
    logic iq_issue_valid1;
    logic iq_issue_ready0;
    logic iq_issue_ready1;
    logic [4:0] iq_op0;
    logic [4:0] iq_op1;
    logic [5:0] iq_pdst0;
    logic [5:0] iq_pdst1;
    logic [31:0] iq_src1_0;
    logic [31:0] iq_src1_1;
    logic [31:0] iq_src2_0;
    logic [31:0] iq_src2_1;
    logic [31:0] iq_imm0;
    logic [31:0] iq_imm1;
    logic [4:0] iq_rob0;
    logic [4:0] iq_rob1;
    logic [3:0] iq_occ;

    logic mq_enq_valid0;
    logic mq_enq_valid1;
    logic mq_enq_ready0;
    logic mq_enq_ready1;
    uop_t mq_enq_u0;
    uop_t mq_enq_u1;
    logic [4:0] mq_enq_rob0;
    logic [4:0] mq_enq_rob1;
    logic mq_issue_valid0;
    logic mq_issue_valid1;
    logic mq_issue_ready0;
    logic mq_issue_ready1;
    logic mq_is_load0;
    logic mq_is_load1;
    logic mq_is_store0;
    logic mq_is_store1;
    logic [1:0] mq_size0;
    logic [1:0] mq_size1;
    logic mq_unsigned0;
    logic mq_unsigned1;
    logic [5:0] mq_pdst0;
    logic [5:0] mq_pdst1;
    logic [31:0] mq_base0;
    logic [31:0] mq_base1;
    logic [31:0] mq_sdata0;
    logic [31:0] mq_sdata1;
    logic [31:0] mq_imm0;
    logic [31:0] mq_imm1;
    logic [4:0] mq_rob0;
    logic [4:0] mq_rob1;
    logic [3:0] mq_occ;
    logic mq_fire0;
    logic mq_fire1;

    logic [1:0] ex_v;
    logic [1:0] ex_md;
    logic [1:0] ex_ctl;
    logic [1:0] ex_sys;
    logic [1:0] ex_csr;
    logic [1:0] ex_exc;
    logic [1:0] ex_misal;
    logic [1:0] ex_wr;
    logic [1:0] ex_ready;
    logic [1:0] ex_fire;
    logic [1:0] ex_sel;
    logic [1:0] md_take;
    logic [1:0] bu_taken;
    logic [1:0] bu_redirect;
    logic [1:0] br_mis;
    logic [4:0] ex_rob [0:1];
    logic [4:0] ex_op [0:1];
    logic [5:0] ex_pdst [0:1];
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
    logic [31:0] br_rpc [0:1];
    uop_t ex_u [0:1];

    logic [1:0] alu_zero;
    logic [1:0] alu_lt;
    logic [1:0] alu_ltu;
    logic [1:0] br_recov_valid;
    logic [1:0] br_flush_fe;
    logic [1:0] br_flush_dec;
    logic [1:0] br_flush_ren;
    logic [1:0] br_flush_iss;
    logic [4:0] br_rtag [0:1];

    logic md_cand0;
    logic md_cand1;
    logic md_req_valid;
    logic md_req_ready;
    logic [2:0] md_req_f3;
    logic [31:0] md_req_a;
    logic [31:0] md_req_b;
    logic md_rsp_valid;
    logic md_rsp_ready;
    logic [31:0] md_rsp_result;
    logic [5:0] md_pdst;
    logic [4:0] md_rob;
    logic md_wr;

    logic [2:0] mstate;
    logic m_is_load;
    logic [5:0] m_pdst;
    logic [4:0] m_rob;
    logic m_wr;
    logic [1:0] m_size;
    logic m_unsigned;
    logic [31:0] m_addr;
    logic [31:0] m_data;
    logic m_err;
    logic m_misaligned;
    logic m_launch;
    logic m_launch_load;
    logic m_launch_store;
    uop_t head_u;

    logic lsu_req_valid;
    logic lsu_req_ready;
    logic lsu_mem_req_valid;
    logic lsu_mem_req_ready;
    logic lsu_mem_req_write;
    logic [31:0] lsu_mem_req_addr;
    logic [31:0] lsu_mem_req_wdata;
    logic [3:0] lsu_mem_req_strb;
    logic lsu_mem_rsp_valid;
    logic lsu_result_valid;
    logic [31:0] lsu_result_data;
    logic lsu_busy;
    logic lsu_misaligned;

    logic mem_c_valid;
    logic [5:0] mem_c_pdst;
    logic [31:0] mem_c_data;
    logic [4:0] mem_c_rob;
    logic mem_c_wr;
    logic mem_c_exc;
    logic [31:0] mem_c_cause;

    logic lq_alloc_valid;
    logic lq_alloc_ready;
    logic [5:0] lq_alloc_tag;
    logic sq_alloc_valid;
    logic sq_alloc_ready;
    logic [5:0] sq_alloc_tag;
    logic lq_retire_valid;
    logic [5:0] lq_retire_tag;
    logic sq_retire_valid;
    logic [5:0] sq_retire_tag;
    logic lq_upd_valid;
    logic [5:0] lq_upd_tag;
    logic [31:0] lq_upd_addr;
    logic sq_upd_valid;
    logic [5:0] sq_upd_tag;
    logic [31:0] sq_upd_addr;
    logic [31:0] sq_upd_data;
    logic [3:0] sq_upd_wstrb;
    logic lq_head_valid;
    logic [5:0] lq_head_tag;
    logic [31:0] lq_head_addr;
    logic [31:0] lq_head_data;
    logic lq_head_addr_valid;
    logic lq_head_data_valid;
    logic sq_head_valid;
    logic [5:0] sq_head_tag;
    logic [31:0] sq_head_addr;
    logic [31:0] sq_head_data;
    logic [3:0] sq_head_wstrb;
    logic sq_head_addr_valid;
    logic sq_head_data_valid;
    logic lq_full;
    logic lq_empty;
    logic [4:0] lq_count;
    logic sq_full;
    logic sq_empty;
    logic [4:0] sq_count;

    logic [3:0] ws_valid;
    logic [23:0] ws_pdst;
    logic [127:0] ws_data;
    logic [1:0] ws_out_valid;
    logic [11:0] ws_out_pdst;
    logic [63:0] ws_out_data;
    logic [3:0] ws_out_index;
    logic [3:0] ws_chosen;
    logic [4:0] src_rob [0:3];
    logic [3:0] src_wr;
    logic [3:0] src_exc;
    logic [31:0] src_cause [0:3];
    logic [5:0] src_pdst [0:3];
    logic [31:0] src_data [0:3];
    logic [1:0] lane_v;
    logic [1:0] lane_wr;
    logic [1:0] lane_exc;
    logic [5:0] lane_pdst [0:1];
    logic [31:0] lane_data [0:1];
    logic [4:0] lane_rob [0:1];
    logic [31:0] lane_cause [0:1];
    logic [1:0] lane_sel [0:1];
    logic wk_valid0;
    logic wk_valid1;
    logic [5:0] wk_pdst0;
    logic [5:0] wk_pdst1;
    logic [31:0] wk_data0;
    logic [31:0] wk_data1;
    logic prf_we0;
    logic prf_we1;
    logic [5:0] prf_waddr0;
    logic [5:0] prf_waddr1;
    logic [31:0] prf_wdata0;
    logic [31:0] prf_wdata1;
    logic wb_cv0;
    logic wb_cv1;
    logic [4:0] wb_ctag0;
    logic [4:0] wb_ctag1;
    logic [31:0] wb_cres0;
    logic [31:0] wb_cres1;
    logic cb_v0;
    logic cb_v1;
    logic [4:0] cb_tag0;
    logic [4:0] cb_tag1;
    logic [31:0] cb_res0;
    logic [31:0] cb_res1;

    logic csr_read_valid;
    logic [11:0] csr_read_addr;
    logic [31:0] csr_read_data;
    logic csr_write_valid;
    logic [11:0] csr_write_addr;
    logic [31:0] csr_write_data;
    logic [2:0] csr_write_cmd;
    logic csr_trap_valid;
    logic [31:0] csr_trap_pc;
    logic [31:0] csr_trap_cause;
    logic csr_mret;
    logic [31:0] csr_trap_vector;
    logic [31:0] csr_epc;
    logic csr_gie;

    uop_t cu0;
    uop_t cu1;
    logic exc0;
    logic exc1;
    logic mis0;
    logic mis1;
    logic mret0;
    logic mret1;
    logic stop0;
    logic normal0;
    logic retire0_ok;
    logic retire1_ok;
    logic ev_exc;
    logic ev_mret;
    logic ev_mis;
    logic [31:0] ev_pc;
    logic [31:0] ev_cause;
    logic [31:0] ev_mis_pc;
    logic [4:0] ev_mis_tag;
    logic ec_trap_valid;
    logic ec_trap_is_int;
    logic [31:0] ec_trap_pc;
    logic [31:0] ec_trap_cause;
    logic [31:0] ec_trap_tval;
    logic [31:0] ec_trap_vector;
    logic ec_flush;
    logic rc_exc_valid_q;
    logic [31:0] rc_exc_pc_q;
    logic rc_br_valid_q;
    logic [31:0] rc_br_pc_q;
    logic [4:0] rc_br_tag_q;
    logic rc_recovery_valid;
    logic [31:0] rc_recovery_pc;
    logic rc_is_branch;
    logic rc_is_exception;
    logic rc_is_interrupt;
    logic [4:0] rc_recovery_tag;
    logic rc_flush_fe;
    logic rc_flush_dec;
    logic rc_flush_ren;
    logic rc_flush_iss;
    logic rc_flush_pipe;

    logic cs_rd_ready0;
    logic cs_rd_ready1;
    logic cs_aw_valid0;
    logic [4:0] cs_aw_rd0;
    logic [31:0] cs_aw_data0;
    logic cs_aw_valid1;
    logic [4:0] cs_aw_rd1;
    logic [31:0] cs_aw_data1;
    logic cs_free_valid0;
    logic [5:0] cs_free_preg0;
    logic cs_free_valid1;
    logic [5:0] cs_free_preg1;
    logic cs_ret_valid0;
    logic [4:0] cs_ret_idx0;
    logic [31:0] cs_ret_pc0;
    logic cs_ret_valid1;
    logic [4:0] cs_ret_idx1;
    logic [31:0] cs_ret_pc1;

    logic [31:0] arch_rd_data0;
    logic [31:0] arch_rd_data1;
    logic [31:0] pc_shadow;

    assign flush = rc_recovery_valid;
    assign flush_pc = rc_recovery_pc;

    assign fe_redirect_valid = flush || pred_redirect_valid;
    assign fe_redirect_pc = flush ? flush_pc : pred_redirect_pc;

    rv32im_pc_g u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .fetch_advance(consume_pkt),
        .redirect_valid(fe_redirect_valid),
        .redirect_target(fe_redirect_pc),
        .pc(pc_shadow)
    );

    // (fetch stage instance removed: see pipelined fetch below)

    rv32im_branch_predictor_g u_branch_predictor (
        .clk(clk),
        .rst_n(rst_n),
        .predict_valid0(pr_valid0),
        .predict_pc0(fs_pc0),
        .predict_is_return0(is_return_inst(fs_inst0)),
        .predict_valid1(pr_valid1),
        .predict_pc1(fs_pc1),
        .predict_is_return1(is_return_inst(fs_inst1)),
        .fetch_accept0(pr_accept0),
        .fetch_accept1(pr_accept1),
        .predict_taken0(pr_taken0),
        .predict_target0(pr_target0),
        .history_snapshot0(pr_hist0),
        .predict_taken1(pr_taken1),
        .predict_target1(pr_target1),
        .history_snapshot1(pr_hist1),
        .update_valid(pr_update_valid),
        .update_pc(pr_update_pc),
        .update_history(pr_update_hist),
        .actual_taken(pr_update_taken),
        .update_target(pr_update_target),
        .ras_push_valid(ras_push_valid),
        .ras_push_addr(ras_push_addr),
        .ras_pop_valid(ras_pop_valid),
        .ras_checkpoint_save(1'b0),
        .ras_checkpoint_ptr(),
        .ras_checkpoint_count(),
        .ras_checkpoint_stack(),
        .ras_checkpoint_restore(flush),
        .ras_restore_ptr(rasc_ptr),
        .ras_restore_count(rasc_count),
        .ras_restore_stack(rasc_stack),
        .ghr_restore_valid(flush),
        .ghr_restore_value(ghr_fix_q)
    );

    rv32im_fetch_queue_g u_fetch_queue (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .in_valid0(q_in_valid0),
        .in_pc0(q_in_pc0),
        .in_instruction0(q_in_inst0),
        .in_predicted_taken0(q_in_pt0),
        .in_predicted_target0(q_in_tgt0),
        .in_history_snapshot0(q_in_hist0),
        .in_ready0(q_in_ready0),
        .in_valid1(q_in_valid1),
        .in_pc1(q_in_pc1),
        .in_instruction1(q_in_inst1),
        .in_predicted_taken1(q_in_pt1),
        .in_predicted_target1(q_in_tgt1),
        .in_history_snapshot1(q_in_hist1),
        .in_ready1(q_in_ready1),
        .out_valid0(q_out_valid0),
        .out_pc0(q_out_pc0),
        .out_instruction0(q_out_inst0),
        .out_predicted_taken0(q_out_pt0),
        .out_predicted_target0(q_out_tgt0),
        .out_history_snapshot0(q_out_hist0),
        .out_ready0(q_out_ready0),
        .out_valid1(q_out_valid1),
        .out_pc1(q_out_pc1),
        .out_instruction1(q_out_inst1),
        .out_predicted_taken1(q_out_pt1),
        .out_predicted_target1(q_out_tgt1),
        .out_history_snapshot1(q_out_hist1),
        .out_ready1(q_out_ready1),
        .queue_count(q_count)
    );

    always_comb begin
        fq_room = (q_count <= 4'd6);
        consume_pkt = fs_valid0 && fq_room && !flush;
        fs_ready0 = fq_room && !flush;
        fs_ready1 = fq_room && !flush;

        pr_valid0 = fs_valid0 && !skip0;
        pr_valid1 = fs_valid0;
        pt0 = pr_taken0 && !skip0;
        pt1 = pr_taken1;
        pr_accept0 = consume_pkt && !skip0;
        pr_accept1 = consume_pkt && (skip0 || !pt0);

        pred_redirect_valid = consume_pkt && (skip0 ? pt1 : (pt0 || pt1));
        pred_redirect_pc = (!skip0 && pt0) ? pr_target0 : pr_target1;

        q_in_valid0 = consume_pkt;
        q_in_valid1 = consume_pkt && !skip0 && !pt0;

        if (skip0) begin
            q_in_pc0 = fs_pc1;
            q_in_inst0 = fs_inst1;
            q_in_pt0 = pt1;
            q_in_tgt0 = pt1 ? pr_target1 : (fs_pc1 + 32'd4);
            q_in_hist0 = pr_hist1;
        end else begin
            q_in_pc0 = fs_pc0;
            q_in_inst0 = fs_inst0;
            q_in_pt0 = pt0;
            q_in_tgt0 = pt0 ? pr_target0 : (fs_pc0 + 32'd4);
            q_in_hist0 = pr_hist0;
        end

        q_in_pc1 = fs_pc1;
        q_in_inst1 = fs_inst1;
        q_in_pt1 = pt1;
        q_in_tgt1 = pt1 ? pr_target1 : (fs_pc1 + 32'd4);
        q_in_hist1 = pr_hist1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            skip0 <= 1'b0;
        end else if (fe_redirect_valid) begin
            skip0 <= fe_redirect_pc[2];
        end else if (consume_pkt) begin
            skip0 <= 1'b0;
        end
    end

    assign abort = flush || pred_redirect_valid;

    // ------------------------------------------------------------------
    // Pipelined fetch: one 8-byte packet requested per cycle.
    //   cycle N   : request f_pc accepted by the I-cache
    //   cycle N+1 : I-cache RESP state -> packet goes straight into the fetch queue
    //               while the next request (f_pc+8) is accepted in the same cycle
    // A squashed (flush / predicted-taken redirect) request still in the cache is
    // marked stale and dropped when its response appears.
    // ------------------------------------------------------------------
    localparam bit FAST_REDIRECT = 1'b1;
    logic [31:0] f_pc;
    logic [31:0] f_pend_pc;
    logic        f_pend;
    logic        f_stale;
    logic        f_resp_take;
    logic        f_req_fire;

    always_comb begin
        fs_valid0 = i_resp_valid && f_pend && !f_stale;
        fs_valid1 = fs_valid0;
        fs_pc0    = f_pend_pc;
        fs_pc1    = f_pend_pc + 32'd4;
        fs_inst0  = i_resp_error[0] ? 32'h0000007F : i_resp_data[31:0];
        fs_inst1  = i_resp_error[1] ? 32'h0000007F : i_resp_data[63:32];

        i_resp_ready = consume_pkt || (i_resp_valid && (f_stale || flush));
        f_resp_take  = i_resp_valid && i_resp_ready;

        // FAST_REDIRECT: when the packet being consumed is predicted taken, the I-cache request for the
        // target is issued in the same cycle (no bubble) instead of one cycle later.
        i_req_valid  = FAST_REDIRECT ? !flush : !abort;
        i_req_addr   = (FAST_REDIRECT && pred_redirect_valid) ? {fe_redirect_pc[31:3], 3'b000} : f_pc;
        f_req_fire   = i_req_valid && i_req_ready;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_pc      <= 32'd0;
            f_pend_pc <= 32'd0;
            f_pend    <= 1'b0;
            f_stale   <= 1'b0;
        end else if (flush || (!FAST_REDIRECT && pred_redirect_valid)) begin
            f_pc <= {fe_redirect_pc[31:3], 3'b000};
            if (f_resp_take) begin
                f_pend  <= 1'b0;
                f_stale <= 1'b0;
            end else if (f_pend) begin
                f_stale <= 1'b1;      // response still to come: drop it later
            end
        end else begin
            if (f_req_fire) begin
                f_pend    <= 1'b1;
                f_pend_pc <= i_req_addr;
                f_pc      <= i_req_addr + 32'd8;
                f_stale   <= 1'b0;
            end else if (pred_redirect_valid) begin
                f_pc      <= {fe_redirect_pc[31:3], 3'b000};
                if (f_resp_take) begin
                    f_pend  <= 1'b0;
                    f_stale <= 1'b0;
                end
            end else if (f_resp_take) begin
                f_pend  <= 1'b0;
                f_stale <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------
    // Speculative RAS: updated when a packet is accepted at fetch, restored from the
    // commit-side RAS (u_ras_commit) on every flush.
    // ------------------------------------------------------------------
    logic sp_op0_push, sp_op0_pop, sp_op1_push, sp_op1_pop;

    function automatic logic is_call_inst(input logic [31:0] ins);
        is_call_inst = ((ins[6:0] == 7'b1101111) || (ins[6:0] == 7'b1100111)) &&
                       (ins[11:7] == 5'd1 || ins[11:7] == 5'd5);
    endfunction

    always_comb begin
        sp_op0_push = pr_accept0 && is_call_inst(fs_inst0);
        sp_op0_pop  = pr_accept0 && is_return_inst(fs_inst0) && !is_call_inst(fs_inst0);
        sp_op1_push = pr_accept1 && is_call_inst(fs_inst1);
        sp_op1_pop  = pr_accept1 && is_return_inst(fs_inst1) && !is_call_inst(fs_inst1);
        ras_push_valid = 1'b0;
        ras_push_addr  = 32'd0;
        ras_pop_valid  = 1'b0;
        if (sp_op1_push) begin
            ras_push_valid = 1'b1;
            ras_push_addr  = fs_pc1 + 32'd4;
            ras_pop_valid  = sp_op0_pop;
        end else if (sp_op1_pop) begin
            if (!sp_op0_push)
                ras_pop_valid = 1'b1;
        end else if (sp_op0_push) begin
            ras_push_valid = 1'b1;
            ras_push_addr  = fs_pc0 + 32'd4;
        end else if (sp_op0_pop) begin
            ras_pop_valid = 1'b1;
        end
    end

    rv32im_decode_stage_g u_decode_stage (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .in_valid0(q_out_valid0),
        .in_instruction0(q_out_inst0),
        .in_pc0(q_out_pc0),
        .in_predicted_pc0(q_out_tgt0),
        .in_valid1(q_out_valid1),
        .in_instruction1(q_out_inst1),
        .in_pc1(q_out_pc1),
        .in_predicted_pc1(q_out_tgt1),
        .in_ready0(dc_in_ready0),
        .in_ready1(dc_in_ready1),
        .out_valid0(dc_valid0),
        .out_instruction0(dc_inst0),
        .out_pc0(dc_pc0),
        .out_predicted_pc0(dc_ppc0),
        .out_illegal0(dc_illegal0),
        .out_opcode0(dc_opcode0),
        .out_funct3_0(dc_f3_0),
        .out_funct7_0(dc_f7_0),
        .out_rs1_0(dc_rs1_0),
        .out_rs2_0(dc_rs2_0),
        .out_rd0(dc_rd0),
        .out_uses_rs1_0(dc_urs1_0),
        .out_uses_rs2_0(dc_urs2_0),
        .out_writes_rd0(dc_wr0),
        .out_immediate0(dc_imm0),
        .out_alu_op0(dc_aluop0),
        .out_branch_op0(dc_brop0),
        .out_memory_size0(dc_msize0),
        .out_load_unsigned0(dc_lu0),
        .out_is_branch0(dc_br0),
        .out_is_jal0(dc_jal0),
        .out_is_jalr0(dc_jalr0),
        .out_is_load0(dc_ld0),
        .out_is_store0(dc_st0),
        .out_is_muldiv0(dc_md0),
        .out_is_system0(dc_sys0),
        .out_is_fence0(dc_fence0),
        .out_valid1(dc_valid1),
        .out_instruction1(dc_inst1),
        .out_pc1(dc_pc1),
        .out_predicted_pc1(dc_ppc1),
        .out_illegal1(dc_illegal1),
        .out_opcode1(dc_opcode1),
        .out_funct3_1(dc_f3_1),
        .out_funct7_1(dc_f7_1),
        .out_rs1_1(dc_rs1_1),
        .out_rs2_1(dc_rs2_1),
        .out_rd1(dc_rd1),
        .out_uses_rs1_1(dc_urs1_1),
        .out_uses_rs2_1(dc_urs2_1),
        .out_writes_rd1(dc_wr1),
        .out_immediate1(dc_imm1),
        .out_alu_op1(dc_aluop1),
        .out_branch_op1(dc_brop1),
        .out_memory_size1(dc_msize1),
        .out_load_unsigned1(dc_lu1),
        .out_is_branch1(dc_br1),
        .out_is_jal1(dc_jal1),
        .out_is_jalr1(dc_jalr1),
        .out_is_load1(dc_ld1),
        .out_is_store1(dc_st1),
        .out_is_muldiv1(dc_md1),
        .out_is_system1(dc_sys1),
        .out_is_fence1(dc_fence1)
    );

    always_comb begin
        csr0 = dc_sys0 && (dc_f3_0 != 3'b000);
        csr1 = dc_sys1 && (dc_f3_1 != 3'b000);
        wr_eff0 = dc_wr0 && (dc_rd0 != 5'd0) && !dc_illegal0;
        wr_eff1 = dc_wr1 && (dc_rd1 != 5'd0) && !dc_illegal1;
        ld0 = dc_ld0 && !dc_illegal0;
        ld1 = dc_ld1 && !dc_illegal1;
        st0 = dc_st0 && !dc_illegal0;
        st1 = dc_st1 && !dc_illegal1;
        mem0 = ld0 || st0;
        mem1 = ld1 || st1;
        gate0 = !(csr0 && !rob_empty);
        gate1 = !csr1 && !(ld0 && ld1) && !(st0 && st1);
        d_valid0 = dc_valid0 && gate0;
        d_valid1 = dc_valid1 && gate0 && gate1;
        q_out_ready0 = disp_fire0;
        q_out_ready1 = disp_fire1;
    end

    rv32im_rename_g u_rename (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .in_valid0(d_valid0 && disp_in_ready0),
        .in_rs1_0(dc_rs1_0),
        .in_rs2_0(dc_rs2_0),
        .in_rd0(dc_rd0),
        .in_uses_rs1_0(dc_urs1_0),
        .in_uses_rs2_0(dc_urs2_0),
        .in_writes_rd0(wr_eff0),
        .in_valid1(d_valid1 && disp_in_ready1),
        .in_rs1_1(dc_rs1_1),
        .in_rs2_1(dc_rs2_1),
        .in_rd1(dc_rd1),
        .in_uses_rs1_1(dc_urs1_1),
        .in_uses_rs2_1(dc_urs2_1),
        .in_writes_rd1(wr_eff1),
        .in_ready0(ren_in_ready0),
        .in_ready1(ren_in_ready1),
        .out_valid0(ren_out_valid0),
        .out_rs1_0(ren_rs1_0),
        .out_rs2_0(ren_rs2_0),
        .out_rd0(ren_rd0),
        .out_old_rd0(ren_old0),
        .out_valid1(ren_out_valid1),
        .out_rs1_1(ren_rs1_1),
        .out_rs2_1(ren_rs2_1),
        .out_rd1(ren_rd1),
        .out_old_rd1(ren_old1),
        .free_valid0(cs_free_valid0),
        .free_preg0(cs_free_preg0),
        .free_valid1(cs_free_valid1),
        .free_preg1(cs_free_preg1),
        .checkpoint_restore(flush),
        .restore_map(restore_map),
        .restore_bitmap(restore_bm),
        .checkpoint_map(ren_ckpt_map),
        .free_bitmap(ren_free_bitmap)
    );

    rv32im_prf_g u_prf (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr0(ren_rs1_0),
        .read_data0(prf_rd0),
        .read_addr1(ren_rs2_0),
        .read_data1(prf_rd1),
        .read_addr2(ren_rs1_1),
        .read_data2(prf_rd2),
        .read_addr3(ren_rs2_1),
        .read_data3(prf_rd3),
        .write_valid0(prf_we0),
        .write_addr0(prf_waddr0),
        .write_data0(prf_wdata0),
        .write_valid1(prf_we1),
        .write_addr1(prf_waddr1),
        .write_data1(prf_wdata1)
    );

    rv32im_operand_bypass_g u_bypass_0 (
        .src_ready0(sb_ready[ren_rs1_0]),
        .src_tag0(ren_rs1_0),
        .src_data0(prf_rd0),
        .src_ready1(sb_ready[ren_rs2_0]),
        .src_tag1(ren_rs2_0),
        .src_data1(prf_rd1),
        .bypass_valid0(wk_valid0),
        .bypass_pdst0(wk_pdst0),
        .bypass_data0(wk_data0),
        .bypass_valid1(wk_valid1),
        .bypass_pdst1(wk_pdst1),
        .bypass_data1(wk_data1),
        .operand_ready0(byp0_r1),
        .operand_data0(byp0_d1),
        .operand_ready1(byp0_r2),
        .operand_data1(byp0_d2)
    );

    rv32im_operand_bypass_g u_bypass_1 (
        .src_ready0(sb_ready[ren_rs1_1] && !(ren_out_valid0 && wr_eff0 && ren_rs1_1 == ren_rd0)),
        .src_tag0(ren_rs1_1),
        .src_data0(prf_rd2),
        .src_ready1(sb_ready[ren_rs2_1] && !(ren_out_valid0 && wr_eff0 && ren_rs2_1 == ren_rd0)),
        .src_tag1(ren_rs2_1),
        .src_data1(prf_rd3),
        .bypass_valid0(wk_valid0),
        .bypass_pdst0(wk_pdst0),
        .bypass_data0(wk_data0),
        .bypass_valid1(wk_valid1),
        .bypass_pdst1(wk_pdst1),
        .bypass_data1(wk_data1),
        .operand_ready0(byp1_r1),
        .operand_data0(byp1_d1),
        .operand_ready1(byp1_r2),
        .operand_data1(byp1_d2)
    );

    always_comb begin
        u0 = '0;
        u0.pc = dc_pc0;
        u0.pred_pc = dc_ppc0;
        u0.imm = dc_imm0;
        u0.instr = dc_inst0;
        u0.src1_data = byp0_d1;
        u0.src2_data = byp0_d2;
        u0.rd = dc_rd0;
        u0.pdst = ren_rd0;
        u0.old_pdst = ren_old0;
        u0.psrc1 = ren_rs1_0;
        u0.psrc2 = ren_rs2_0;
        u0.alu_op = dc_aluop0;
        u0.funct3 = dc_f3_0;
        u0.ghist = q_out_hist0;
        u0.msize = dc_msize0;
        u0.src1_ready = byp0_r1;
        u0.src2_ready = byp0_r2;
        u0.writes_rd = wr_eff0;
        u0.uses_rs2 = dc_urs2_0;
        u0.is_auipc = (dc_opcode0 == 7'b0010111);
        u0.is_branch = dc_br0 && !dc_illegal0;
        u0.is_jal = dc_jal0;
        u0.is_jalr = dc_jalr0 && !dc_illegal0;
        u0.is_load = ld0;
        u0.is_store = st0;
        u0.is_muldiv = dc_md0;
        u0.is_system = dc_sys0 && !dc_illegal0;
        u0.is_fence = dc_fence0;
        u0.illegal = dc_illegal0;
        u0.load_unsigned = dc_lu0;
        u0.pred_taken = q_out_pt0;

        u1 = '0;
        u1.pc = dc_pc1;
        u1.pred_pc = dc_ppc1;
        u1.imm = dc_imm1;
        u1.instr = dc_inst1;
        u1.src1_data = byp1_d1;
        u1.src2_data = byp1_d2;
        u1.rd = dc_rd1;
        u1.pdst = ren_rd1;
        u1.old_pdst = ren_old1;
        u1.psrc1 = ren_rs1_1;
        u1.psrc2 = ren_rs2_1;
        u1.alu_op = dc_aluop1;
        u1.funct3 = dc_f3_1;
        u1.ghist = q_out_hist1;
        u1.msize = dc_msize1;
        u1.src1_ready = byp1_r1;
        u1.src2_ready = byp1_r2;
        u1.writes_rd = wr_eff1;
        u1.uses_rs2 = dc_urs2_1;
        u1.is_auipc = (dc_opcode1 == 7'b0010111);
        u1.is_branch = dc_br1 && !dc_illegal1;
        u1.is_jal = dc_jal1;
        u1.is_jalr = dc_jalr1 && !dc_illegal1;
        u1.is_load = ld1;
        u1.is_store = st1;
        u1.is_muldiv = dc_md1;
        u1.is_system = dc_sys1 && !dc_illegal1;
        u1.is_fence = dc_fence1;
        u1.illegal = dc_illegal1;
        u1.load_unsigned = dc_lu1;
        u1.pred_taken = q_out_pt1;
    end

    assign disp_in_uop0 = u0;
    assign disp_in_uop1 = u1;

    logic [4:0] lq_free5;
    logic [4:0] sq_free5;
    logic [3:0] mfe;

    always_comb begin
        rob_free_count = 6'd32 - rob_occ;
        intq_free_count = 4'd8 - iq_occ;
        mfe = 4'd8 - mq_occ;
        lq_free5 = 5'd16 - lq_count;
        sq_free5 = 5'd16 - sq_count;
        if (lq_free5 < {1'b0, mfe})
            mfe = lq_free5[3:0];
        if (sq_free5 < {1'b0, mfe})
            mfe = sq_free5[3:0];
        memq_free_count = mfe;
    end

    rv32im_dispatch_g #(
        .UOP_WIDTH(UW),
        .ROB_COUNT_BITS(6),
        .QUEUE_COUNT_BITS(4)
    ) u_dispatch (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid0(ren_out_valid0),
        .in_uop0(disp_in_uop0),
        .in_is_memory0(mem0),
        .in_valid1(ren_out_valid1),
        .in_uop1(disp_in_uop1),
        .in_is_memory1(mem1),
        .in_ready0(disp_in_ready0),
        .in_ready1(disp_in_ready1),
        .rob_free_count(rob_free_count),
        .intq_free_count(intq_free_count),
        .memq_free_count(memq_free_count),
        .rob_valid0(disp_rob_valid0),
        .rob_valid1(disp_rob_valid1),
        .rob_uop0(disp_rob_uop0),
        .rob_uop1(disp_rob_uop1),
        .intq_valid0(disp_intq_valid0),
        .intq_valid1(disp_intq_valid1),
        .intq_uop0(disp_intq_uop0),
        .intq_uop1(disp_intq_uop1),
        .memq_valid0(disp_memq_valid0),
        .memq_valid1(disp_memq_valid1),
        .memq_uop0(disp_memq_uop0),
        .memq_uop1(disp_memq_uop1),
        .dispatch_fire0(disp_fire0),
        .dispatch_fire1(disp_fire1)
    );

    logic bad_pred0;
    logic bad_pred1;
    logic fencei0;
    logic fencei1;

    assign rob_u0 = disp_rob_uop0;
    assign rob_u1 = disp_rob_uop1;
    assign bad_pred0 = !(rob_u0.is_branch || rob_u0.is_jal || rob_u0.is_jalr) &&
                       (rob_u0.pred_pc != (rob_u0.pc + 32'd4));
    assign bad_pred1 = !(rob_u1.is_branch || rob_u1.is_jal || rob_u1.is_jalr) &&
                       (rob_u1.pred_pc != (rob_u1.pc + 32'd4));
    assign fencei0 = rob_u0.is_fence && rob_u0.instr[12];
    assign fencei1 = rob_u1.is_fence && rob_u1.instr[12];
    assign intq_u0 = disp_intq_uop0;
    assign intq_u1 = disp_intq_uop1;
    assign memq_u0 = disp_memq_uop0;
    assign memq_u1 = disp_memq_uop1;

    assign rob_idx0 = rob_cidx0 + rob_occ[4:0];
    assign rob_idx1 = rob_idx0 + 5'd1;

    rv32im_rob_g u_rob (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .dispatch_valid0(disp_rob_valid0),
        .dispatch_ready0(),
        .dispatch_pc0(rob_u0.pc),
        .dispatch_rd0(rob_u0.rd),
        .dispatch_pdst0(rob_u0.pdst),
        .dispatch_old_pdst0(rob_u0.old_pdst),
        .dispatch_writes_rd0(rob_u0.writes_rd),
        .dispatch_valid1(disp_rob_valid1),
        .dispatch_ready1(),
        .dispatch_pc1(rob_u1.pc),
        .dispatch_rd1(rob_u1.rd),
        .dispatch_pdst1(rob_u1.pdst),
        .dispatch_old_pdst1(rob_u1.old_pdst),
        .dispatch_writes_rd1(rob_u1.writes_rd),
        .complete_valid0(cb_v0),
        .complete_idx0(cb_tag0),
        .complete_data0(cb_res0),
        .complete_exception0(lane_exc[0]),
        .complete_cause0(lane_cause[0]),
        .complete_valid1(cb_v1),
        .complete_idx1(cb_tag1),
        .complete_data1(cb_res1),
        .complete_exception1(lane_exc[1]),
        .complete_cause1(lane_cause[1]),
        .commit_valid0(rob_cv0),
        .commit_ready0(rob_cr0),
        .commit_idx0(rob_cidx0),
        .commit_pc0(rob_cpc0),
        .commit_rd0(rob_crd0),
        .commit_pdst0(rob_cpdst0),
        .commit_old_pdst0(rob_cold0),
        .commit_data0(rob_cdata0),
        .commit_writes_rd0(rob_cwr0),
        .commit_exception0(rob_cexc0),
        .commit_cause0(rob_ccause0),
        .commit_valid1(rob_cv1),
        .commit_ready1(rob_cr1),
        .commit_idx1(rob_cidx1),
        .commit_pc1(rob_cpc1),
        .commit_rd1(rob_crd1),
        .commit_pdst1(rob_cpdst1),
        .commit_old_pdst1(rob_cold1),
        .commit_data1(rob_cdata1),
        .commit_writes_rd1(rob_cwr1),
        .commit_exception1(rob_cexc1),
        .commit_cause1(rob_ccause1),
        .occupancy(rob_occ),
        .empty(rob_empty),
        .full(rob_full)
    );

    always_comb begin
        iq_enq_valid0 = disp_intq_valid0 || disp_intq_valid1;
        iq_enq_u0 = disp_intq_valid0 ? intq_u0 : intq_u1;
        iq_enq_rob0 = disp_intq_valid0 ? rob_idx0 : rob_idx1;
        iq_enq_valid1 = disp_intq_valid0 && disp_intq_valid1;
        iq_enq_u1 = intq_u1;
        iq_enq_rob1 = rob_idx1;

        mq_enq_valid0 = disp_memq_valid0 || disp_memq_valid1;
        mq_enq_u0 = disp_memq_valid0 ? memq_u0 : memq_u1;
        mq_enq_rob0 = disp_memq_valid0 ? rob_idx0 : rob_idx1;
        mq_enq_valid1 = disp_memq_valid0 && disp_memq_valid1;
        mq_enq_u1 = memq_u1;
        mq_enq_rob1 = rob_idx1;
    end

    rv32im_int_issue_queue_g #(
        .DEPTH(8)
    ) u_int_issue_queue (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .enq_valid0(iq_enq_valid0),
        .enq_ready0(iq_enq_ready0),
        .enq_op0(iq_enq_u0.alu_op),
        .enq_pdst0(iq_enq_u0.pdst),
        .enq_psrc1_0(iq_enq_u0.psrc1),
        .enq_psrc2_0(iq_enq_u0.psrc2),
        .enq_imm0(iq_enq_u0.imm),
        .enq_rob_idx0(iq_enq_rob0),
        .enq_src1_ready0(iq_enq_u0.src1_ready),
        .enq_src1_data0(iq_enq_u0.src1_data),
        .enq_src2_ready0(iq_enq_u0.src2_ready),
        .enq_src2_data0(iq_enq_u0.src2_data),
        .enq_valid1(iq_enq_valid1),
        .enq_ready1(iq_enq_ready1),
        .enq_op1(iq_enq_u1.alu_op),
        .enq_pdst1(iq_enq_u1.pdst),
        .enq_psrc1_1(iq_enq_u1.psrc1),
        .enq_psrc2_1(iq_enq_u1.psrc2),
        .enq_imm1(iq_enq_u1.imm),
        .enq_rob_idx1(iq_enq_rob1),
        .enq_src1_ready1(iq_enq_u1.src1_ready),
        .enq_src1_data1(iq_enq_u1.src1_data),
        .enq_src2_ready1(iq_enq_u1.src2_ready),
        .enq_src2_data1(iq_enq_u1.src2_data),
        .wakeup_valid0(wk_valid0),
        .wakeup_pdst0(wk_pdst0),
        .wakeup_data0(wk_data0),
        .wakeup_valid1(wk_valid1),
        .wakeup_pdst1(wk_pdst1),
        .wakeup_data1(wk_data1),
        .issue_valid0(iq_issue_valid0),
        .issue_ready0(iq_issue_ready0),
        .issue_op0(iq_op0),
        .issue_pdst0(iq_pdst0),
        .issue_src1_0(iq_src1_0),
        .issue_src2_0(iq_src2_0),
        .issue_imm0(iq_imm0),
        .issue_rob_idx0(iq_rob0),
        .issue_valid1(iq_issue_valid1),
        .issue_ready1(iq_issue_ready1),
        .issue_op1(iq_op1),
        .issue_pdst1(iq_pdst1),
        .issue_src1_1(iq_src1_1),
        .issue_src2_1(iq_src2_1),
        .issue_imm1(iq_imm1),
        .issue_rob_idx1(iq_rob1),
        .occupancy(iq_occ)
    );

    rv32im_mem_issue_queue_g #(
        .DEPTH(8)
    ) u_mem_issue_queue (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .enq_valid0(mq_enq_valid0),
        .enq_ready0(mq_enq_ready0),
        .enq_is_load0(mq_enq_u0.is_load),
        .enq_is_store0(mq_enq_u0.is_store),
        .enq_size0(mq_enq_u0.msize),
        .enq_unsigned0(mq_enq_u0.load_unsigned),
        .enq_pdst0(mq_enq_u0.pdst),
        .enq_psrc_base0(mq_enq_u0.psrc1),
        .enq_psrc_store0(mq_enq_u0.psrc2),
        .enq_imm0(mq_enq_u0.imm),
        .enq_rob_idx0(mq_enq_rob0),
        .enq_base_ready0(mq_enq_u0.src1_ready),
        .enq_base_data0(mq_enq_u0.src1_data),
        .enq_store_ready0(mq_enq_u0.src2_ready),
        .enq_store_data0(mq_enq_u0.src2_data),
        .enq_valid1(mq_enq_valid1),
        .enq_ready1(mq_enq_ready1),
        .enq_is_load1(mq_enq_u1.is_load),
        .enq_is_store1(mq_enq_u1.is_store),
        .enq_size1(mq_enq_u1.msize),
        .enq_unsigned1(mq_enq_u1.load_unsigned),
        .enq_pdst1(mq_enq_u1.pdst),
        .enq_psrc_base1(mq_enq_u1.psrc1),
        .enq_psrc_store1(mq_enq_u1.psrc2),
        .enq_imm1(mq_enq_u1.imm),
        .enq_rob_idx1(mq_enq_rob1),
        .enq_base_ready1(mq_enq_u1.src1_ready),
        .enq_base_data1(mq_enq_u1.src1_data),
        .enq_store_ready1(mq_enq_u1.src2_ready),
        .enq_store_data1(mq_enq_u1.src2_data),
        .wakeup_valid0(wk_valid0),
        .wakeup_pdst0(wk_pdst0),
        .wakeup_data0(wk_data0),
        .wakeup_valid1(wk_valid1),
        .wakeup_pdst1(wk_pdst1),
        .wakeup_data1(wk_data1),
        .issue_valid0(mq_issue_valid0),
        .issue_ready0(mq_issue_ready0),
        .issue_is_load0(mq_is_load0),
        .issue_is_store0(mq_is_store0),
        .issue_size0(mq_size0),
        .issue_unsigned0(mq_unsigned0),
        .issue_pdst0(mq_pdst0),
        .issue_base0(mq_base0),
        .issue_store_data0(mq_sdata0),
        .issue_imm0(mq_imm0),
        .issue_rob_idx0(mq_rob0),
        .issue_valid1(mq_issue_valid1),
        .issue_ready1(mq_issue_ready1),
        .issue_is_load1(mq_is_load1),
        .issue_is_store1(mq_is_store1),
        .issue_size1(mq_size1),
        .issue_unsigned1(mq_unsigned1),
        .issue_pdst1(mq_pdst1),
        .issue_base1(mq_base1),
        .issue_store_data1(mq_sdata1),
        .issue_imm1(mq_imm1),
        .issue_rob_idx1(mq_rob1),
        .occupancy(mq_occ)
    );

    integer ti;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ti = 0; ti < 32; ti = ti + 1)
                uop_tbl[ti] <= '0;
        end else begin
            if (disp_rob_valid0)
                uop_tbl[rob_idx0] <= rob_u0;
            if (disp_rob_valid1)
                uop_tbl[rob_idx1] <= rob_u1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sb_ready <= '1;
        end else if (flush) begin
            sb_ready <= '1;
        end else begin
            if (wk_valid0)
                sb_ready[wk_pdst0] <= 1'b1;
            if (wk_valid1)
                sb_ready[wk_pdst1] <= 1'b1;
            if (disp_fire0 && wr_eff0)
                sb_ready[ren_rd0] <= 1'b0;
            if (disp_fire1 && wr_eff1)
                sb_ready[ren_rd1] <= 1'b0;
        end
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
            ex_u[i] = uop_tbl[ex_rob[i]];
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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mis_valid <= '0;
            for (int i = 0; i < 32; i = i + 1)
                mis_pc[i] <= '0;
        end else if (flush) begin
            mis_valid <= '0;
        end else begin
            if (disp_rob_valid0) begin
                mis_valid[rob_idx0] <= bad_pred0 || fencei0;
                mis_pc[rob_idx0] <= rob_u0.pc + 32'd4;
            end
            if (disp_rob_valid1) begin
                mis_valid[rob_idx1] <= bad_pred1 || fencei1;
                mis_pc[rob_idx1] <= rob_u1.pc + 32'd4;
            end
            for (int i = 0; i < 2; i = i + 1) begin
                if (ex_fire[i] && ex_ctl[i] && br_mis[i]) begin
                    mis_valid[ex_rob[i]] <= 1'b1;
                    mis_pc[ex_rob[i]] <= br_rpc[i];
                end
            end
        end
    end

    // Predictor training: the predictor has ONE update port, but two control instructions can
    // resolve in the same cycle.  The loser is parked in a 1-entry pending register and sent
    // on a later cycle instead of being dropped (a dropped update left some branches untrained).
    logic        pu_v;
    logic [31:0] pu_pc;
    logic [3:0]  pu_hist;
    logic        pu_taken;
    logic [31:0] pu_tgt;
    logic        pu_nv;
    logic [31:0] pu_npc;
    logic [3:0]  pu_nhist;
    logic        pu_ntaken;
    logic [31:0] pu_ntgt;
    logic        f0v, f1v;

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
        if (cs_ret_valid1 && cu1.is_load) begin
            lq_retire_valid = 1'b1;
            lq_retire_tag = {1'b0, cs_ret_idx1};
        end
        if (cs_ret_valid1 && cu1.is_store) begin
            sq_retire_valid = 1'b1;
            sq_retire_tag = {1'b0, cs_ret_idx1};
        end
        if (cs_ret_valid0 && cu0.is_load) begin
            lq_retire_valid = 1'b1;
            lq_retire_tag = {1'b0, cs_ret_idx0};
        end
        if (cs_ret_valid0 && cu0.is_store) begin
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

    // Load launch.  EARLY_LOAD = 1: scan the ROB from the head, in program order, for the oldest
    // load whose address is known and that has not been launched yet; the scan stops at the first
    // older store (conservative memory ordering).  Several loads can therefore be launched back to
    // back without waiting for earlier loads to retire.  EARLY_LOAD = 0: original behaviour
    // (a load is launched only when it is at the ROB head).
    // LOAD_MODE 0 : load launches only when it is at the ROB head (original, slowest)
    // LOAD_MODE 1 : oldest load in the LQ launches early (known good: all 11 benchmarks PASSED)
    // LOAD_MODE 2 : ROB scan, several loads launched back to back  (EXPERIMENTAL - broke stores+loads tests)
    // B2B         : memory FSM accepts a new op in the cycle the previous one completes (EXPERIMENTAL)
    localparam int LOAD_MODE = 2;
    localparam bit B2B = 1'b1;
    logic [4:0] ld_dist;
    logic [4:0] sq_dist;
    logic older_store;
    uop_t ld_u;
    uop_t lu;
    logic [4:0] ld_tag5;
    logic [4:0] ld_pick;
    logic [4:0] scan_idx;
    logic scan_found;
    logic scan_blocked;
    logic ld_ready;
    logic m_free;
    logic m_squash;
    logic m_last_valid;
    logic [4:0] m_last_tag;
    logic [31:0] ld_av;
    logic [31:0] ld_launched;
    logic [31:0] ld_addr_tbl [0:31];
    logic [31:0] ld_addr_sel;

    always_comb begin
        head_u = uop_tbl[rob_cidx0];
        scan_found = 1'b0;
        scan_blocked = 1'b0;
        scan_idx = '0;
        ld_pick = rob_cidx0;
        for (int k = 0; k < 32; k = k + 1) begin
            scan_idx = rob_cidx0 + 5'(k);
            if (!scan_found && !scan_blocked && (6'(k) < rob_occ)) begin
                if (uop_tbl[scan_idx].is_store)
                    scan_blocked = 1'b1;
                else if (uop_tbl[scan_idx].is_load && ld_av[scan_idx] && !ld_launched[scan_idx]) begin
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
                       uop_tbl[ld_tag5].is_load &&
                       !(m_last_valid && (m_last_tag == ld_tag5));
            ld_addr_sel = lq_head_addr;
        end else begin
            ld_ready = !rob_cv0 && head_u.is_load && lq_head_valid &&
                       (lq_head_tag == {1'b0, rob_cidx0}) && lq_head_addr_valid;
            ld_tag5 = rob_cidx0;
            ld_addr_sel = lq_head_addr;
        end
        ld_u = uop_tbl[ld_tag5];
        // the single memory FSM may take a new operation in the cycle the previous one completes
        m_free = (mstate == M_IDLE) || (B2B && mstate == M_WAIT && d_resp_valid);
        m_launch_load = m_free && !flush && !rob_empty && ld_ready;
        // stores start only from IDLE: in the completion cycle of a store its ROB entry is not yet
        // marked done, so a back-to-back start would launch the same store twice
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
            // back-to-back launch: new operation starts in the cycle the previous one completes
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
            // load completes in the same cycle the data returns
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
        // a load squashed by a flush must not complete into the new stream
        if (m_is_load && (m_squash || flush))
            mem_c_valid = 1'b0;
    end

    always_comb begin
        cu0 = uop_tbl[rob_cidx0];
        cu1 = uop_tbl[rob_cidx1];
        exc0 = rob_cv0 && rob_cexc0;
        mis0 = rob_cv0 && !rob_cexc0 && mis_valid[rob_cidx0];
        mret0 = rob_cv0 && !rob_cexc0 && cu0.is_system &&
                (cu0.funct3 == 3'b000) && (cu0.instr[31:20] == 12'h302);
        stop0 = exc0 || mis0 || mret0;
        normal0 = rob_cv0 && !stop0;
        retire0_ok = rob_cv0 && !rob_cexc0;
        exc1 = normal0 && rob_cv1 && rob_cexc1;
        mis1 = normal0 && rob_cv1 && !rob_cexc1 && mis_valid[rob_cidx1];
        mret1 = normal0 && rob_cv1 && !rob_cexc1 && cu1.is_system &&
                (cu1.funct3 == 3'b000) && (cu1.instr[31:20] == 12'h302);
        retire1_ok = normal0 && rob_cv1 && !rob_cexc1;

        rob_cr0 = retire0_ok && !flush;
        rob_cr1 = retire1_ok && !flush;

        ev_exc = exc0 || exc1;
        ev_mret = mret0 || mret1;
        ev_mis = mis0 || mis1;
        ev_pc = exc0 ? rob_cpc0 : rob_cpc1;
        ev_cause = exc0 ? rob_ccause0 : rob_ccause1;
        ev_mis_pc = mis0 ? mis_pc[rob_cidx0] : mis_pc[rob_cidx1];
        ev_mis_tag = mis0 ? rob_cidx0 : rob_cidx1;
    end

    rv32im_commit_stage_g u_commit_stage (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .rob_commit_valid0(retire0_ok),
        .rob_commit_ready0(cs_rd_ready0),
        .rob_commit_rob_idx0(rob_cidx0),
        .rob_commit_pc0(rob_cpc0),
        .rob_commit_rd0(rob_crd0),
        .rob_commit_pdst0(rob_cpdst0),
        .rob_commit_old_pdst0(rob_cold0),
        .rob_commit_data0(rob_cdata0),
        .rob_commit_writes_rd0(rob_cwr0),
        .rob_commit_valid1(retire1_ok),
        .rob_commit_ready1(cs_rd_ready1),
        .rob_commit_rob_idx1(rob_cidx1),
        .rob_commit_pc1(rob_cpc1),
        .rob_commit_rd1(rob_crd1),
        .rob_commit_pdst1(rob_cpdst1),
        .rob_commit_old_pdst1(rob_cold1),
        .rob_commit_data1(rob_cdata1),
        .rob_commit_writes_rd1(rob_cwr1),
        .arch_write_valid0(cs_aw_valid0),
        .arch_write_rd0(cs_aw_rd0),
        .arch_write_data0(cs_aw_data0),
        .arch_write_valid1(cs_aw_valid1),
        .arch_write_rd1(cs_aw_rd1),
        .arch_write_data1(cs_aw_data1),
        .free_valid0(cs_free_valid0),
        .free_preg0(cs_free_preg0),
        .free_valid1(cs_free_valid1),
        .free_preg1(cs_free_preg1),
        .retire_valid0(cs_ret_valid0),
        .retire_rob_idx0(cs_ret_idx0),
        .retire_pc0(cs_ret_pc0),
        .retire_valid1(cs_ret_valid1),
        .retire_rob_idx1(cs_ret_idx1),
        .retire_pc1(cs_ret_pc1)
    );

    rv32im_arch_state_g u_arch_state (
        .clk(clk),
        .rst_n(rst_n),
        .commit_valid0(cs_aw_valid0),
        .commit_rd0(cs_aw_rd0),
        .commit_data0(cs_aw_data0),
        .commit_valid1(cs_aw_valid1),
        .commit_rd1(cs_aw_rd1),
        .commit_data1(cs_aw_data1),
        .read_addr0(5'd0),
        .read_data0(arch_rd_data0),
        .read_addr1(5'd0),
        .read_data1(arch_rd_data1)
    );

    rv32im_exception_controller_g #(
        .ADDR_BITS(32)
    ) u_exception_controller (
        .exception_valid(ev_exc),
        .exception_pc(ev_pc),
        .exception_cause(ev_cause),
        .exception_tval(32'd0),
        .interrupt_valid(1'b0),
        .interrupt_pc(32'd0),
        .interrupt_cause(32'd0),
        .trap_ready(1'b1),
        .mtvec(csr_trap_vector),
        .trap_valid(ec_trap_valid),
        .trap_is_interrupt(ec_trap_is_int),
        .trap_pc(ec_trap_pc),
        .trap_cause(ec_trap_cause),
        .trap_tval(ec_trap_tval),
        .trap_vector(ec_trap_vector),
        .flush_pipeline(ec_flush)
    );

    rv32im_csr_g #(
        .ADDR_BITS(12),
        .DATA_BITS(32)
    ) u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .read_valid(csr_read_valid),
        .read_addr(csr_read_addr),
        .read_data(csr_read_data),
        .write_valid(csr_write_valid),
        .write_addr(csr_write_addr),
        .write_data(csr_write_data),
        .write_cmd(csr_write_cmd),
        .trap_valid(ec_trap_valid),
        .trap_pc(ec_trap_pc),
        .trap_cause(ec_trap_cause),
        .trap_value(ec_trap_tval),
        .mret(ev_mret),
        .retire_count({1'b0, cs_ret_valid0} + {1'b0, cs_ret_valid1}),
        .external_interrupts(32'd0),
        .trap_vector(csr_trap_vector),
        .exception_pc(csr_epc),
        .global_interrupt_enable(csr_gie)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rc_exc_valid_q <= 1'b0;
            rc_exc_pc_q <= '0;
            rc_br_valid_q <= 1'b0;
            rc_br_pc_q <= '0;
            rc_br_tag_q <= '0;
        end else begin
            rc_exc_valid_q <= ev_exc || ev_mret;
            rc_exc_pc_q <= ev_exc ? ec_trap_vector : csr_epc;
            rc_br_valid_q <= ev_mis;
            rc_br_pc_q <= ev_mis_pc;
            rc_br_tag_q <= ev_mis_tag;
        end
    end

    rv32im_recovery_controller_g #(
        .ADDR_BITS(32),
        .ROB_TAG_BITS(5)
    ) u_recovery_controller (
        .clk(clk),
        .rst_n(rst_n),
        .branch_recovery_valid(rc_br_valid_q),
        .branch_recovery_pc(rc_br_pc_q),
        .branch_recovery_rob_tag(rc_br_tag_q),
        .exception_valid(rc_exc_valid_q),
        .exception_pc(rc_exc_pc_q),
        .interrupt_valid(1'b0),
        .interrupt_pc(32'd0),
        .recovery_valid(rc_recovery_valid),
        .recovery_pc(rc_recovery_pc),
        .recovery_is_branch(rc_is_branch),
        .recovery_is_exception(rc_is_exception),
        .recovery_is_interrupt(rc_is_interrupt),
        .recovery_rob_tag(rc_recovery_tag),
        .flush_frontend(rc_flush_fe),
        .flush_decode(rc_flush_dec),
        .flush_rename(rc_flush_ren),
        .flush_issue(rc_flush_iss),
        .flush_pipeline(rc_flush_pipe)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i = i + 1)
                cmap[i] <= 6'(i);
        end else begin
            if (cs_aw_valid0)
                cmap[cs_aw_rd0] <= rob_cpdst0;
            if (cs_aw_valid1)
                cmap[cs_aw_rd1] <= rob_cpdst1;
        end
    end

    always_comb begin
        restore_bm = '1;
        restore_bm[0] = 1'b0;
        restore_map = '0;
        for (int i = 1; i < 32; i = i + 1) begin
            restore_bm[cmap[i]] = 1'b0;
            restore_map[i*6 +: 6] = cmap[i];
        end

        ras_op0_push = cs_ret_valid0 && (cu0.is_jal || cu0.is_jalr) && (cu0.rd == 5'd1 || cu0.rd == 5'd5);
        ras_op0_pop = !ras_op0_push && cs_ret_valid0 && cu0.is_jalr && cu0.rd == 5'd0 &&
                      (cu0.instr[19:15] == 5'd1 || cu0.instr[19:15] == 5'd5);
        ras_op1_push = cs_ret_valid1 && (cu1.is_jal || cu1.is_jalr) && (cu1.rd == 5'd1 || cu1.rd == 5'd5);
        ras_op1_pop = !ras_op1_push && cs_ret_valid1 && cu1.is_jalr && cu1.rd == 5'd0 &&
                      (cu1.instr[19:15] == 5'd1 || cu1.instr[19:15] == 5'd5);

        rasc_push_valid = 1'b0;
        rasc_push_addr = 32'd0;
        rasc_pop_valid = 1'b0;
        if (ras_op1_push) begin
            rasc_push_valid = 1'b1;
            rasc_push_addr = cs_ret_pc1 + 32'd4;
            rasc_pop_valid = ras_op0_pop;
        end else if (ras_op1_pop) begin
            if (!ras_op0_push)
                rasc_pop_valid = 1'b1;
        end else if (ras_op0_push) begin
            rasc_push_valid = 1'b1;
            rasc_push_addr = cs_ret_pc0 + 32'd4;
        end else if (ras_op0_pop) begin
            rasc_pop_valid = 1'b1;
        end

        i_invalidate = (rob_cr0 && cu0.is_fence && cu0.instr[12]) ||
                       (rob_cr1 && cu1.is_fence && cu1.instr[12]);

        core_busy = !rob_empty;
        core_halted = 1'b0;
        exception_valid = ec_trap_valid;
        exception_pc = ec_trap_pc;
    end

    rv32im_ras_g #(.RAS_DEPTH(8)) u_ras_commit (
        .clk(clk),
        .rst_n(rst_n),
        .push_valid(rasc_push_valid),
        .push_addr(rasc_push_addr),
        .pop_valid(rasc_pop_valid),
        .checkpoint_save(1'b0),
        .checkpoint_ptr(),
        .checkpoint_count(),
        .checkpoint_stack(),
        .checkpoint_restore(1'b0),
        .restore_ptr(3'd0),
        .restore_count(4'd0),
        .restore_stack('0),
        .ras_valid(),
        .ras_target(),
        .cur_ptr(rasc_ptr),
        .cur_count(rasc_count),
        .cur_stack(rasc_stack)
    );

    // global-history repair: after a mispredict, history = (snapshot << 1) | actual outcome
    logic [3:0]  mis_h;
    logic [31:0] mis_bpc;
    always_comb begin
        mis_h   = mis0 ? cu0.ghist : cu1.ghist;
        mis_bpc = mis0 ? rob_cpc0 : rob_cpc1;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ghr_fix_q <= 4'd0;
        else if (ev_mis)
            ghr_fix_q <= {mis_h[2:0], (ev_mis_pc != (mis_bpc + 32'd4))};
    end

endmodule