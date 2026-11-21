module rv32im_rename_dispatch_dec_ren_prf_g #(
    parameter int UW = 251
) (
    input  logic clk,
    input  logic rst_n,

    input  logic         flush,
    input  logic         q_out_valid0,
    input  logic         q_out_valid1,
    input  logic [31:0]  q_out_pc0,
    input  logic [31:0]  q_out_pc1,
    input  logic [31:0]  q_out_inst0,
    input  logic [31:0]  q_out_inst1,
    input  logic         q_out_pt0,
    input  logic         q_out_pt1,
    input  logic [31:0]  q_out_tgt0,
    input  logic [31:0]  q_out_tgt1,
    input  logic [3:0]   q_out_hist0,
    input  logic [3:0]   q_out_hist1,
    input  logic [191:0] restore_map,
    input  logic [63:0]  restore_bm,
    input  logic [5:0]   rob_occ,
    input  logic         rob_empty,
    input  logic [3:0]   iq_occ,
    input  logic [3:0]   mq_occ,
    input  logic [4:0]   lq_count,
    input  logic [4:0]   sq_count,
    input  logic         wk_valid0,
    input  logic         wk_valid1,
    input  logic [5:0]   wk_pdst0,
    input  logic [5:0]   wk_pdst1,
    input  logic [31:0]  wk_data0,
    input  logic [31:0]  wk_data1,
    input  logic         prf_we0,
    input  logic         prf_we1,
    input  logic [5:0]   prf_waddr0,
    input  logic [5:0]   prf_waddr1,
    input  logic [31:0]  prf_wdata0,
    input  logic [31:0]  prf_wdata1,
    input  logic         cs_free_valid0,
    input  logic [5:0]   cs_free_preg0,
    input  logic         cs_free_valid1,
    input  logic [5:0]   cs_free_preg1,

    output logic          q_out_ready0,
    output logic          q_out_ready1,
    output logic          ld0,
    output logic          ld1,
    output logic          st0,
    output logic          st1,
    output logic          disp_rob_valid0,
    output logic          disp_rob_valid1,
    output logic [UW-1:0] disp_rob_uop0,
    output logic [UW-1:0] disp_rob_uop1,
    output logic          disp_intq_valid0,
    output logic          disp_intq_valid1,
    output logic [UW-1:0] disp_intq_uop0,
    output logic [UW-1:0] disp_intq_uop1,
    output logic          disp_memq_valid0,
    output logic          disp_memq_valid1,
    output logic [UW-1:0] disp_memq_uop0,
    output logic [UW-1:0] disp_memq_uop1,
    output logic          disp_fire0,
    output logic          disp_fire1
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

    logic         dc_in_ready0;
    logic         dc_in_ready1;
    logic         dc_valid0;
    logic         dc_valid1;
    logic [31:0]  dc_inst0;
    logic [31:0]  dc_inst1;
    logic [31:0]  dc_pc0;
    logic [31:0]  dc_pc1;
    logic [31:0]  dc_ppc0;
    logic [31:0]  dc_ppc1;
    logic         dc_illegal0;
    logic         dc_illegal1;
    logic [6:0]   dc_opcode0;
    logic [6:0]   dc_opcode1;
    logic [2:0]   dc_f3_0;
    logic [2:0]   dc_f3_1;
    logic [6:0]   dc_f7_0;
    logic [6:0]   dc_f7_1;
    logic [4:0]   dc_rs1_0;
    logic [4:0]   dc_rs1_1;
    logic [4:0]   dc_rs2_0;
    logic [4:0]   dc_rs2_1;
    logic [4:0]   dc_rd0;
    logic [4:0]   dc_rd1;
    logic         dc_urs1_0;
    logic         dc_urs1_1;
    logic         dc_urs2_0;
    logic         dc_urs2_1;
    logic         dc_wr0;
    logic         dc_wr1;
    logic [31:0]  dc_imm0;
    logic [31:0]  dc_imm1;
    logic [4:0]   dc_aluop0;
    logic [4:0]   dc_aluop1;
    logic [2:0]   dc_brop0;
    logic [2:0]   dc_brop1;
    logic [1:0]   dc_msize0;
    logic [1:0]   dc_msize1;
    logic         dc_lu0;
    logic         dc_lu1;
    logic         dc_br0;
    logic         dc_br1;
    logic         dc_jal0;
    logic         dc_jal1;
    logic         dc_jalr0;
    logic         dc_jalr1;
    logic         dc_ld0;
    logic         dc_ld1;
    logic         dc_st0;
    logic         dc_st1;
    logic         dc_md0;
    logic         dc_md1;
    logic         dc_sys0;
    logic         dc_sys1;
    logic         dc_fence0;
    logic         dc_fence1;
    logic         csr0;
    logic         csr1;
    logic         gate0;
    logic         gate1;
    logic         d_valid0;
    logic         d_valid1;
    logic         wr_eff0;
    logic         wr_eff1;
    logic         mem0;
    logic         mem1;
    logic         ren_in_ready0;
    logic         ren_in_ready1;
    logic         ren_out_valid0;
    logic         ren_out_valid1;
    logic [5:0]   ren_rs1_0;
    logic [5:0]   ren_rs2_0;
    logic [5:0]   ren_rd0;
    logic [5:0]   ren_old0;
    logic [5:0]   ren_rs1_1;
    logic [5:0]   ren_rs2_1;
    logic [5:0]   ren_rd1;
    logic [5:0]   ren_old1;
    logic [191:0] ren_ckpt_map;
    logic [63:0]  ren_free_bitmap;
    logic [31:0]  prf_rd0;
    logic [31:0]  prf_rd1;
    logic [31:0]  prf_rd2;
    logic [31:0]  prf_rd3;
    logic [63:0]  sb_ready;
    logic         byp0_r1;
    logic [31:0]  byp0_d1;
    logic         byp0_r2;
    logic [31:0]  byp0_d2;
    logic         byp1_r1;
    logic [31:0]  byp1_d1;
    logic         byp1_r2;
    logic [31:0]  byp1_d2;
    uop_t u0;
    uop_t u1;
    logic [UW-1:0] disp_in_uop0;
    logic [UW-1:0] disp_in_uop1;
    logic          disp_in_ready0;
    logic          disp_in_ready1;
    logic [5:0]    rob_free_count;
    logic [3:0]    intq_free_count;
    logic [3:0]    memq_free_count;
    logic [4:0]    lq_free5;
    logic [4:0]    sq_free5;
    logic [3:0]    mfe;

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

endmodule