module rv32im_branch_predictor_g #(
    parameter int GHR_BITS = 4,
    parameter int PHT_ENTRIES = 256,
    parameter int BTB_ENTRIES = 128,
    parameter int RAS_DEPTH = 8
) (
    input logic clk,
    input logic rst_n,

    input logic predict_valid0,
    input logic [31:0] predict_pc0,
    input logic predict_is_return0,

    input logic predict_valid1,
    input logic [31:0] predict_pc1,
    input logic predict_is_return1,

    input logic fetch_accept0,
    input logic fetch_accept1,

    output logic predict_taken0,
    output logic [31:0] predict_target0,
    output logic [GHR_BITS-1:0] history_snapshot0,

    output logic predict_taken1,
    output logic [31:0] predict_target1,
    output logic [GHR_BITS-1:0] history_snapshot1,

    input logic update_valid,
    input logic [31:0] update_pc,
    input logic [GHR_BITS-1:0] update_history,
    input logic actual_taken,
    input logic [31:0] update_target,

    input logic ras_push_valid,
    input logic [31:0] ras_push_addr,
    input logic ras_pop_valid,

    input logic ras_checkpoint_save,
    output logic [$clog2(RAS_DEPTH)-1:0] ras_checkpoint_ptr,
    output logic [$clog2(RAS_DEPTH+1)-1:0] ras_checkpoint_count,
    output logic [RAS_DEPTH*32-1:0] ras_checkpoint_stack,

    input logic ras_checkpoint_restore,
    input logic [$clog2(RAS_DEPTH)-1:0] ras_restore_ptr,
    input logic [$clog2(RAS_DEPTH+1)-1:0] ras_restore_count,
    input logic [RAS_DEPTH*32-1:0] ras_restore_stack,
    input logic ghr_restore_valid,
    input logic [GHR_BITS-1:0] ghr_restore_value
);

    logic [GHR_BITS-1:0] global_history;
    logic [GHR_BITS-1:0] history_after_lane0;

    logic bht_taken0;
    logic bht_taken1;

    logic btb_hit0;
    logic btb_hit1;

    logic [31:0] btb_target0;
    logic [31:0] btb_target1;

    logic ras_valid;
    logic [31:0] ras_target;

    logic update_btb_valid;

    logic predicted_taken0;
    logic predicted_taken1;

    logic accepted_branch0;
    logic accepted_branch1;

    assign history_snapshot0 = global_history;
    assign history_snapshot1 = history_after_lane0;

    assign update_btb_valid = update_valid && actual_taken;

    always_comb begin
        predicted_taken0 = predict_valid0 && btb_hit0 && bht_taken0;
        predicted_taken1 = predict_valid1 && btb_hit1 && bht_taken1;

        predict_target0 = '0;
        predict_target1 = '0;

        if (btb_hit0)
            predict_target0 = btb_target0;

        if (btb_hit1)
            predict_target1 = btb_target1;

        if (predict_valid0 && predict_is_return0 && ras_valid) begin
            predicted_taken0 = 1'b1;
            predict_target0 = ras_target;
        end

        if (predict_valid1 && predict_is_return1 && ras_valid) begin
            predicted_taken1 = 1'b1;
            predict_target1 = ras_target;
        end

        predict_taken0 = predicted_taken0;
        predict_taken1 = predicted_taken1;

        history_after_lane0 = global_history;

        if (predict_valid0 && btb_hit0)
            history_after_lane0 =
                (global_history << 1) | GHR_BITS'(bht_taken0);

        accepted_branch0 =
            fetch_accept0 &&
            predict_valid0 &&
            btb_hit0;

        accepted_branch1 =
            fetch_accept1 &&
            predict_valid1 &&
            btb_hit1;
    end

    rv32im_gshare_bht_g #(
        .GHR_BITS(GHR_BITS),
        .PHT_ENTRIES(PHT_ENTRIES)
    ) u_gshare_bht_g (
        .clk(clk),
        .rst_n(rst_n),

        .predict_pc0(predict_pc0),
        .predict_history0(history_snapshot0),
        .predict_taken0(bht_taken0),

        .predict_pc1(predict_pc1),
        .predict_history1(history_snapshot1),
        .predict_taken1(bht_taken1),

        .update_valid(update_valid),
        .update_pc(update_pc),
        .update_history(update_history),
        .actual_taken(actual_taken)
    );

    rv32im_btb_g #(
        .BTB_ENTRIES(BTB_ENTRIES)
    ) u_btb_g (
        .clk(clk),
        .rst_n(rst_n),

        .predict_pc0(predict_pc0),
        .predict_hit0(btb_hit0),
        .predict_target0(btb_target0),

        .predict_pc1(predict_pc1),
        .predict_hit1(btb_hit1),
        .predict_target1(btb_target1),

        .update_valid(update_btb_valid),
        .update_pc(update_pc),
        .update_target(update_target)
    );

    rv32im_ras_g #(
        .RAS_DEPTH(RAS_DEPTH)
    ) u_ras_g (
        .clk(clk),
        .rst_n(rst_n),

        .push_valid(ras_push_valid),
        .push_addr(ras_push_addr),

        .pop_valid(ras_pop_valid),

        .checkpoint_save(ras_checkpoint_save),
        .checkpoint_ptr(ras_checkpoint_ptr),
        .checkpoint_count(ras_checkpoint_count),
        .checkpoint_stack(ras_checkpoint_stack),

        .checkpoint_restore(ras_checkpoint_restore),
        .restore_ptr(ras_restore_ptr),
        .restore_count(ras_restore_count),
        .restore_stack(ras_restore_stack),

        .ras_valid(ras_valid),
        .ras_target(ras_target)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_history <= '0;
        end else if (ghr_restore_valid) begin
            global_history <= ghr_restore_value;
        end else if (!ras_checkpoint_restore) begin
            case ({accepted_branch0, accepted_branch1})
                2'b11: begin
                    global_history <=
                        (global_history << 2) |
                        (GHR_BITS'(bht_taken0) << 1) |
                        GHR_BITS'(bht_taken1);
                end

                2'b10: begin
                    global_history <=
                        (global_history << 1) |
                        GHR_BITS'(bht_taken0);
                end

                2'b01: begin
                    global_history <=
                        (global_history << 1) |
                        GHR_BITS'(bht_taken1);
                end

                default: begin
                    global_history <= global_history;
                end
            endcase
        end
    end

endmodule