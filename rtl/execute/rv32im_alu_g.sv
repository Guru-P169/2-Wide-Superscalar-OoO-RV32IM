
module rv32im_alu_g (
    input  logic [4:0]  alu_op,
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    output logic [31:0] result,
    output logic        zero,
    output logic        less_than,
    output logic        less_than_unsigned
);

    localparam logic [4:0] ALU_ADD    = 5'd0;
    localparam logic [4:0] ALU_SUB    = 5'd1;
    localparam logic [4:0] ALU_SLL    = 5'd2;
    localparam logic [4:0] ALU_SLT    = 5'd3;
    localparam logic [4:0] ALU_SLTU   = 5'd4;
    localparam logic [4:0] ALU_XOR    = 5'd5;
    localparam logic [4:0] ALU_SRL    = 5'd6;
    localparam logic [4:0] ALU_SRA    = 5'd7;
    localparam logic [4:0] ALU_OR     = 5'd8;
    localparam logic [4:0] ALU_AND    = 5'd9;
    localparam logic [4:0] ALU_COPY_B = 5'd10;

    always_comb begin
        result = 32'b0;

        less_than = ($signed(operand_a) < $signed(operand_b));
        less_than_unsigned = (operand_a < operand_b);

        case (alu_op)
            ALU_ADD: begin
                result = operand_a + operand_b;
            end

            ALU_SUB: begin
                result = operand_a - operand_b;
            end

            ALU_SLL: begin
                result = operand_a << operand_b[4:0];
            end

            ALU_SLT: begin
                result = {31'b0, less_than};
            end

            ALU_SLTU: begin
                result = {31'b0, less_than_unsigned};
            end

            ALU_XOR: begin
                result = operand_a ^ operand_b;
            end

            ALU_SRL: begin
                result = operand_a >> operand_b[4:0];
            end

            ALU_SRA: begin
                result = $signed(operand_a) >>> operand_b[4:0];
            end

            ALU_OR: begin
                result = operand_a | operand_b;
            end

            ALU_AND: begin
                result = operand_a & operand_b;
            end

            ALU_COPY_B: begin
                result = operand_b;
            end

            default: begin
                result = 32'b0;
            end
        endcase

        zero = (result == 32'b0);
    end

endmodule
