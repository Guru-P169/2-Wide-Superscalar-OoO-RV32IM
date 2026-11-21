module rv32im_issue_intq_memq_g #(
    parameter int UW = 251
) (
    input  logic clk,
    input  logic rst_n,

    input  logic          flush,
    input  logic          disp_intq_valid0,
    input  logic          disp_intq_valid1,
    input  logic [UW-1:0] disp_intq_uop0,
    input  logic [UW-1:0] disp_intq_uop1,
    input  logic          disp_memq_valid0,
    input  logic          disp_memq_valid1,
    input  logic [UW-1:0] disp_memq_uop0,
    input  logic [UW-1:0] disp_memq_uop1,
    input  logic [4:0]    rob_idx0,
    input  logic [4:0]    rob_idx1,
    input  logic          iq_issue_ready0,
    input  logic          iq_issue_ready1,
    input  logic          mq_issue_ready0,
    input  logic          mq_issue_ready1,
    input  logic          wk_valid0,
    input  logic          wk_valid1,
    input  logic [5:0]    wk_pdst0,
    input  logic [5:0]    wk_pdst1,
    input  logic [31:0]   wk_data0,
    input  logic [31:0]   wk_data1,

    output logic        iq_issue_valid0,
    output logic        iq_issue_valid1,
    output logic [4:0]  iq_op0,
    output logic [4:0]  iq_op1,
    output logic [5:0]  iq_pdst0,
    output logic [5:0]  iq_pdst1,
    output logic [31:0] iq_src1_0,
    output logic [31:0] iq_src1_1,
    output logic [31:0] iq_src2_0,
    output logic [31:0] iq_src2_1,
    output logic [31:0] iq_imm0,
    output logic [31:0] iq_imm1,
    output logic [4:0]  iq_rob0,
    output logic [4:0]  iq_rob1,
    output logic [3:0]  iq_occ,
    output logic        mq_issue_valid0,
    output logic        mq_issue_valid1,
    output logic        mq_is_load0,
    output logic        mq_is_load1,
    output logic        mq_is_store0,
    output logic        mq_is_store1,
    output logic [1:0]  mq_size0,
    output logic [1:0]  mq_size1,
    output logic [31:0] mq_base0,
    output logic [31:0] mq_base1,
    output logic [31:0] mq_sdata0,
    output logic [31:0] mq_sdata1,
    output logic [31:0] mq_imm0,
    output logic [31:0] mq_imm1,
    output logic [4:0]  mq_rob0,
    output logic [4:0]  mq_rob1,
    output logic [3:0]  mq_occ
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

    uop_t intq_u0;
    uop_t intq_u1;
    uop_t memq_u0;
    uop_t memq_u1;
    logic iq_enq_valid0;
    logic iq_enq_valid1;
    logic iq_enq_ready0;
    logic iq_enq_ready1;
    uop_t iq_enq_u0;
    uop_t iq_enq_u1;
    logic [4:0] iq_enq_rob0;
    logic [4:0] iq_enq_rob1;
    logic       mq_enq_valid0;
    logic       mq_enq_valid1;
    logic       mq_enq_ready0;
    logic       mq_enq_ready1;
    uop_t mq_enq_u0;
    uop_t mq_enq_u1;
    logic [4:0] mq_enq_rob0;
    logic [4:0] mq_enq_rob1;
    logic       mq_unsigned0;
    logic       mq_unsigned1;
    logic [5:0] mq_pdst0;
    logic [5:0] mq_pdst1;

    assign intq_u0 = disp_intq_uop0;
    assign intq_u1 = disp_intq_uop1;
    assign memq_u0 = disp_memq_uop0;
    assign memq_u1 = disp_memq_uop1;

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

endmodule