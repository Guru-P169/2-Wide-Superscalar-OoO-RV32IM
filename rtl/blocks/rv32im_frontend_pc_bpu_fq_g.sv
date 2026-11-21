module rv32im_frontend_pc_bpu_fq_g (
    input  logic clk,
    input  logic rst_n,

    input  logic         i_req_ready,
    input  logic         i_resp_valid,
    input  logic [63:0]  i_resp_data,
    input  logic [1:0]   i_resp_error,
    input  logic         flush,
    input  logic [2:0]   rasc_ptr,
    input  logic [3:0]   rasc_count,
    input  logic [255:0] rasc_stack,
    input  logic [3:0]   ghr_fix_q,
    input  logic [31:0]  flush_pc,
    input  logic         pr_update_valid,
    input  logic [31:0]  pr_update_pc,
    input  logic [3:0]   pr_update_hist,
    input  logic         pr_update_taken,
    input  logic [31:0]  pr_update_target,
    input  logic         q_out_ready0,
    input  logic         q_out_ready1,

    output logic        i_req_valid,
    output logic [31:0] i_req_addr,
    output logic        i_resp_ready,
    output logic        q_out_valid0,
    output logic        q_out_valid1,
    output logic [31:0] q_out_pc0,
    output logic [31:0] q_out_pc1,
    output logic [31:0] q_out_inst0,
    output logic [31:0] q_out_inst1,
    output logic        q_out_pt0,
    output logic        q_out_pt1,
    output logic [31:0] q_out_tgt0,
    output logic [31:0] q_out_tgt1,
    output logic [3:0]  q_out_hist0,
    output logic [3:0]  q_out_hist1
);

    logic        fe_redirect_valid;
    logic [31:0] fe_redirect_pc;
    logic        fs_valid0;
    logic        fs_valid1;
    logic        fs_ready0;
    logic        fs_ready1;
    logic [31:0] fs_pc0;
    logic [31:0] fs_pc1;
    logic [31:0] fs_inst0;
    logic [31:0] fs_inst1;
    logic        abort;
    logic        skip0;
    logic        fq_room;
    logic        consume_pkt;
    logic        pred_redirect_valid;
    logic [31:0] pred_redirect_pc;
    logic        pr_valid0;
    logic        pr_valid1;
    logic        pr_taken0;
    logic        pr_taken1;
    logic [31:0] pr_target0;
    logic [31:0] pr_target1;
    logic [3:0]  pr_hist0;
    logic [3:0]  pr_hist1;
    logic        pr_accept0;
    logic        pr_accept1;
    logic        pt0;
    logic        pt1;
    logic        ras_push_valid;
    logic [31:0] ras_push_addr;
    logic        ras_pop_valid;
    logic        q_in_valid0;
    logic        q_in_valid1;
    logic [31:0] q_in_pc0;
    logic [31:0] q_in_pc1;
    logic [31:0] q_in_inst0;
    logic [31:0] q_in_inst1;
    logic        q_in_pt0;
    logic        q_in_pt1;
    logic [31:0] q_in_tgt0;
    logic [31:0] q_in_tgt1;
    logic [3:0]  q_in_hist0;
    logic [3:0]  q_in_hist1;
    logic        q_in_ready0;
    logic        q_in_ready1;
    logic [3:0]  q_count;
    logic [31:0] pc_shadow;
    logic [31:0] f_pc;
    logic [31:0] f_pend_pc;
    logic        f_pend;
    logic        f_stale;
    logic        f_resp_take;
    logic        f_req_fire;
    logic        sp_op0_push;
    logic        sp_op0_pop;
    logic        sp_op1_push;
    logic        sp_op1_pop;

    function automatic logic is_return_inst(input logic [31:0] ins);
        is_return_inst = (ins[6:0] == 7'b1100111) &&
                         (ins[11:7] == 5'd0) &&
                         (ins[19:15] == 5'd1 || ins[19:15] == 5'd5);
    endfunction

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

    localparam bit FAST_REDIRECT = 1'b1;

    always_comb begin
        fs_valid0 = i_resp_valid && f_pend && !f_stale;
        fs_valid1 = fs_valid0;
        fs_pc0    = f_pend_pc;
        fs_pc1    = f_pend_pc + 32'd4;
        fs_inst0  = i_resp_error[0] ? 32'h0000007F : i_resp_data[31:0];
        fs_inst1  = i_resp_error[1] ? 32'h0000007F : i_resp_data[63:32];

        i_resp_ready = consume_pkt || (i_resp_valid && (f_stale || flush));
        f_resp_take  = i_resp_valid && i_resp_ready;

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
                f_stale <= 1'b1;
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

endmodule