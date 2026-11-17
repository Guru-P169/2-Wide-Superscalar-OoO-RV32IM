module rv32im_completion_bus_g #(
    parameter int XLEN = 32,
    parameter int ROB_TAG_BITS = 5
) (
    input logic valid_0,
    input logic [ROB_TAG_BITS-1:0] rob_tag_0,
    input logic [XLEN-1:0] result_0,

    input logic valid_1,
    input logic [ROB_TAG_BITS-1:0] rob_tag_1,
    input logic [XLEN-1:0] result_1,

    output logic completion_valid_0,
    output logic [ROB_TAG_BITS-1:0] completion_rob_tag_0,
    output logic [XLEN-1:0] completion_result_0,

    output logic completion_valid_1,
    output logic [ROB_TAG_BITS-1:0] completion_rob_tag_1,
    output logic [XLEN-1:0] completion_result_1
);

    always_comb begin
        completion_valid_0 = valid_0;
        completion_rob_tag_0 = rob_tag_0;
        completion_result_0 = result_0;

        completion_valid_1 = valid_1;
        completion_rob_tag_1 = rob_tag_1;
        completion_result_1 = result_1;
    end

endmodule