
module rv32im_operand_bypass_g #(
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32
) (
    input logic src_ready0,
    input logic [PHYS_BITS-1:0] src_tag0,
    input logic [DATA_BITS-1:0] src_data0,

    input logic src_ready1,
    input logic [PHYS_BITS-1:0] src_tag1,
    input logic [DATA_BITS-1:0] src_data1,

    input logic bypass_valid0,
    input logic [PHYS_BITS-1:0] bypass_pdst0,
    input logic [DATA_BITS-1:0] bypass_data0,

    input logic bypass_valid1,
    input logic [PHYS_BITS-1:0] bypass_pdst1,
    input logic [DATA_BITS-1:0] bypass_data1,

    output logic operand_ready0,
    output logic [DATA_BITS-1:0] operand_data0,

    output logic operand_ready1,
    output logic [DATA_BITS-1:0] operand_data1
);

    always_comb begin
        operand_ready0 = src_ready0;
        operand_data0 = src_data0;

        if (bypass_valid0 && bypass_pdst0 == src_tag0) begin
            operand_ready0 = 1'b1;
            operand_data0 = bypass_data0;
        end

        if (bypass_valid1 && bypass_pdst1 == src_tag0) begin
            operand_ready0 = 1'b1;
            operand_data0 = bypass_data1;
        end

        operand_ready1 = src_ready1;
        operand_data1 = src_data1;

        if (bypass_valid0 && bypass_pdst0 == src_tag1) begin
            operand_ready1 = 1'b1;
            operand_data1 = bypass_data0;
        end

        if (bypass_valid1 && bypass_pdst1 == src_tag1) begin
            operand_ready1 = 1'b1;
            operand_data1 = bypass_data1;
        end
    end

endmodule
