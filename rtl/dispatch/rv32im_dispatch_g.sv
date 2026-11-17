
module rv32im_dispatch_g #(
    parameter int UOP_WIDTH = 192,
    parameter int ROB_COUNT_BITS = 6,
    parameter int QUEUE_COUNT_BITS = 4
) (
    input logic clk,
    input logic rst_n,

    input logic in_valid0,
    input logic [UOP_WIDTH-1:0] in_uop0,
    input logic in_is_memory0,

    input logic in_valid1,
    input logic [UOP_WIDTH-1:0] in_uop1,
    input logic in_is_memory1,

    output logic in_ready0,
    output logic in_ready1,

    input logic [ROB_COUNT_BITS-1:0] rob_free_count,
    input logic [QUEUE_COUNT_BITS-1:0] intq_free_count,
    input logic [QUEUE_COUNT_BITS-1:0] memq_free_count,

    output logic rob_valid0,
    output logic rob_valid1,
    output logic [UOP_WIDTH-1:0] rob_uop0,
    output logic [UOP_WIDTH-1:0] rob_uop1,

    output logic intq_valid0,
    output logic intq_valid1,
    output logic [UOP_WIDTH-1:0] intq_uop0,
    output logic [UOP_WIDTH-1:0] intq_uop1,

    output logic memq_valid0,
    output logic memq_valid1,
    output logic [UOP_WIDTH-1:0] memq_uop0,
    output logic [UOP_WIDTH-1:0] memq_uop1,

    output logic dispatch_fire0,
    output logic dispatch_fire1
);

    logic lane0_queue_ready;
    logic lane1_queue_ready;
    logic lane0_fire;
    logic lane1_fire;

    logic lane0_needs_intq;
    logic lane0_needs_memq;
    logic lane1_needs_intq;
    logic lane1_needs_memq;

    logic [1:0] intq_required;
    logic [1:0] memq_required;
    logic [1:0] rob_required;

    always_comb begin
        lane0_needs_intq = !in_is_memory0;
        lane0_needs_memq = in_is_memory0;

        lane1_needs_intq = !in_is_memory1;
        lane1_needs_memq = in_is_memory1;

        lane0_queue_ready = 1'b0;
        lane1_queue_ready = 1'b0;

        intq_required = 2'd0;
        memq_required = 2'd0;
        rob_required = 2'd0;

        in_ready0 = 1'b0;
        in_ready1 = 1'b0;

        lane0_fire = 1'b0;
        lane1_fire = 1'b0;

        dispatch_fire0 = 1'b0;
        dispatch_fire1 = 1'b0;

        rob_valid0 = 1'b0;
        rob_valid1 = 1'b0;
        rob_uop0 = '0;
        rob_uop1 = '0;

        intq_valid0 = 1'b0;
        intq_valid1 = 1'b0;
        intq_uop0 = '0;
        intq_uop1 = '0;

        memq_valid0 = 1'b0;
        memq_valid1 = 1'b0;
        memq_uop0 = '0;
        memq_uop1 = '0;

        if (lane0_needs_intq)
            lane0_queue_ready = (intq_free_count >= 1);
        else
            lane0_queue_ready = (memq_free_count >= 1);

        in_ready0 =
            (rob_free_count >= 1) &&
            lane0_queue_ready;

        lane0_fire = in_valid0 && in_ready0;

        if (lane0_fire) begin
            rob_required = 2'd1;

            if (lane0_needs_intq)
                intq_required = 2'd1;
            else
                memq_required = 2'd1;
        end

        if (lane1_needs_intq)
            lane1_queue_ready =
                (intq_free_count >=
                    (intq_required + 2'd1));
        else
            lane1_queue_ready =
                (memq_free_count >=
                    (memq_required + 2'd1));

        in_ready1 =
            in_valid0 &&
            in_ready0 &&
            lane1_queue_ready &&
            (rob_free_count >= (rob_required + 2'd1));

        lane1_fire = in_valid1 && in_ready1;

        dispatch_fire0 = lane0_fire;
        dispatch_fire1 = lane1_fire;

        rob_valid0 = lane0_fire;
        rob_valid1 = lane1_fire;

        if (lane0_fire) begin
            rob_uop0 = in_uop0;

            if (lane0_needs_intq) begin
                intq_valid0 = 1'b1;
                intq_uop0 = in_uop0;
            end else begin
                memq_valid0 = 1'b1;
                memq_uop0 = in_uop0;
            end
        end

        if (lane1_fire) begin
            rob_uop1 = in_uop1;

            if (lane1_needs_intq) begin
                intq_valid1 = 1'b1;
                intq_uop1 = in_uop1;
            end else begin
                memq_valid1 = 1'b1;
                memq_uop1 = in_uop1;
            end
        end
    end

endmodule
