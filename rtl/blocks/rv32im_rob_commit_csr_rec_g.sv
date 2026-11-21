module rv32im_rob_commit_csr_rec_g #(
    parameter int UW = 251
) (
    input  logic clk,
    input  logic rst_n,

    input  logic          flush,
    input  logic          disp_rob_valid0,
    input  logic          disp_rob_valid1,
    input  logic [UW-1:0] disp_rob_uop0,
    input  logic [UW-1:0] disp_rob_uop1,
    input  logic [1:0]    ex_ctl,
    input  logic [1:0]    ex_fire,
    input  logic [1:0]    br_mis,
    input  logic [9:0]    ex_rob_flat,
    input  logic [63:0]   br_rpc_flat,
    input  logic [1:0]    lane_exc,
    input  logic [63:0]   lane_cause_flat,
    input  logic          cb_v0,
    input  logic          cb_v1,
    input  logic [4:0]    cb_tag0,
    input  logic [4:0]    cb_tag1,
    input  logic [31:0]   cb_res0,
    input  logic [31:0]   cb_res1,
    input  logic          csr_read_valid,
    input  logic [11:0]   csr_read_addr,
    input  logic          csr_write_valid,
    input  logic [11:0]   csr_write_addr,
    input  logic [31:0]   csr_write_data,
    input  logic [2:0]    csr_write_cmd,
    input  logic [UW-1:0] tbl_cm_data0,
    input  logic [UW-1:0] tbl_cm_data1,

    output logic         i_invalidate,
    output logic         core_busy,
    output logic         core_halted,
    output logic         exception_valid,
    output logic [31:0]  exception_pc,
    output logic [2:0]   rasc_ptr,
    output logic [3:0]   rasc_count,
    output logic [255:0] rasc_stack,
    output logic [3:0]   ghr_fix_q,
    output logic [191:0] restore_map,
    output logic [63:0]  restore_bm,
    output logic [4:0]   rob_idx0,
    output logic [4:0]   rob_idx1,
    output logic [5:0]   rob_occ,
    output logic         rob_empty,
    output logic         rob_cv0,
    output logic [4:0]   rob_cidx0,
    output logic [4:0]   rob_cidx1,
    output logic [31:0]  csr_read_data,
    output logic         rc_recovery_valid,
    output logic [31:0]  rc_recovery_pc,
    output logic         cs_free_valid0,
    output logic [5:0]   cs_free_preg0,
    output logic         cs_free_valid1,
    output logic [5:0]   cs_free_preg1,
    output logic         cs_ret_valid0,
    output logic [4:0]   cs_ret_idx0,
    output logic         cs_ret_valid1,
    output logic [4:0]   cs_ret_idx1
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

    logic        rasc_push_valid;
    logic [31:0] rasc_push_addr;
    logic        rasc_pop_valid;
    logic        ras_op0_push;
    logic        ras_op0_pop;
    logic        ras_op1_push;
    logic        ras_op1_pop;
    logic [5:0]  cmap [0:31];
    uop_t rob_u0;
    uop_t rob_u1;
    logic [31:0] mis_valid;
    logic [31:0] mis_pc [0:31];
    logic        rob_full;
    logic        rob_cv1;
    logic        rob_cr0;
    logic        rob_cr1;
    logic [31:0] rob_cpc0;
    logic [31:0] rob_cpc1;
    logic [4:0]  rob_crd0;
    logic [4:0]  rob_crd1;
    logic [5:0]  rob_cpdst0;
    logic [5:0]  rob_cpdst1;
    logic [5:0]  rob_cold0;
    logic [5:0]  rob_cold1;
    logic [31:0] rob_cdata0;
    logic [31:0] rob_cdata1;
    logic        rob_cwr0;
    logic        rob_cwr1;
    logic        rob_cexc0;
    logic        rob_cexc1;
    logic [31:0] rob_ccause0;
    logic [31:0] rob_ccause1;
    logic [31:0] csr_trap_vector;
    logic [31:0] csr_epc;
    logic        csr_gie;
    uop_t cu0;
    uop_t cu1;
    logic        exc0;
    logic        exc1;
    logic        mis0;
    logic        mis1;
    logic        mret0;
    logic        mret1;
    logic        stop0;
    logic        normal0;
    logic        retire0_ok;
    logic        retire1_ok;
    logic        ev_exc;
    logic        ev_mret;
    logic        ev_mis;
    logic [31:0] ev_pc;
    logic [31:0] ev_cause;
    logic [31:0] ev_mis_pc;
    logic [4:0]  ev_mis_tag;
    logic        ec_trap_valid;
    logic        ec_trap_is_int;
    logic [31:0] ec_trap_pc;
    logic [31:0] ec_trap_cause;
    logic [31:0] ec_trap_tval;
    logic [31:0] ec_trap_vector;
    logic        ec_flush;
    logic        rc_exc_valid_q;
    logic [31:0] rc_exc_pc_q;
    logic        rc_br_valid_q;
    logic [31:0] rc_br_pc_q;
    logic [4:0]  rc_br_tag_q;
    logic        rc_is_branch;
    logic        rc_is_exception;
    logic        rc_is_interrupt;
    logic [4:0]  rc_recovery_tag;
    logic        rc_flush_fe;
    logic        rc_flush_dec;
    logic        rc_flush_ren;
    logic        rc_flush_iss;
    logic        rc_flush_pipe;
    logic        cs_rd_ready0;
    logic        cs_rd_ready1;
    logic        cs_aw_valid0;
    logic [4:0]  cs_aw_rd0;
    logic [31:0] cs_aw_data0;
    logic        cs_aw_valid1;
    logic [4:0]  cs_aw_rd1;
    logic [31:0] cs_aw_data1;
    logic [31:0] cs_ret_pc0;
    logic [31:0] cs_ret_pc1;
    logic [31:0] arch_rd_data0;
    logic [31:0] arch_rd_data1;
    logic        bad_pred0;
    logic        bad_pred1;
    logic        fencei0;
    logic        fencei1;
    logic [3:0]  mis_h;
    logic [31:0] mis_bpc;
    logic [4:0]  ex_rob [0:1];
    logic [31:0] br_rpc [0:1];
    logic [31:0] lane_cause [0:1];

    always_comb begin
        for (int fi = 0; fi < 2; fi = fi + 1)
            ex_rob[fi] = ex_rob_flat[fi*5 +: 5];
    end

    always_comb begin
        for (int fi = 0; fi < 2; fi = fi + 1)
            br_rpc[fi] = br_rpc_flat[fi*32 +: 32];
    end

    always_comb begin
        for (int fi = 0; fi < 2; fi = fi + 1)
            lane_cause[fi] = lane_cause_flat[fi*32 +: 32];
    end

    assign rob_u0 = disp_rob_uop0;
    assign rob_u1 = disp_rob_uop1;
    assign bad_pred0 = !(rob_u0.is_branch || rob_u0.is_jal || rob_u0.is_jalr) &&
                       (rob_u0.pred_pc != (rob_u0.pc + 32'd4));
    assign bad_pred1 = !(rob_u1.is_branch || rob_u1.is_jal || rob_u1.is_jalr) &&
                       (rob_u1.pred_pc != (rob_u1.pc + 32'd4));
    assign fencei0 = rob_u0.is_fence && rob_u0.instr[12];
    assign fencei1 = rob_u1.is_fence && rob_u1.instr[12];
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

    always_comb begin
        cu0 = tbl_cm_s0;
        cu1 = tbl_cm_s1;
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

    uop_t tbl_cm_s0;
    uop_t tbl_cm_s1;
    assign tbl_cm_s0 = tbl_cm_data0;
    assign tbl_cm_s1 = tbl_cm_data1;

endmodule