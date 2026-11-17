
module rv32im_immediate_gen_g (
    input logic [31:0] instruction,

    output logic [31:0] immediate,
    output logic [4:0] zimm,
    output logic illegal_format
);

    logic [6:0] opcode;
    logic [2:0] funct3;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];

    always_comb begin
        immediate = 32'b0;
        zimm = instruction[19:15];
        illegal_format = 1'b0;

        case (opcode)

            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                immediate = {
                    {20{instruction[31]}},
                    instruction[31:20]
                };
            end

            7'b1110011: begin
                if (funct3 == 3'b000) begin
                    immediate = 32'b0;
                end else if (funct3[2]) begin
                    immediate = {27'b0, instruction[19:15]};
                end else begin
                    immediate = {
                        {20{instruction[31]}},
                        instruction[31:20]
                    };
                end
            end

            7'b0100011: begin
                immediate = {
                    {20{instruction[31]}},
                    instruction[31:25],
                    instruction[11:7]
                };
            end

            7'b1100011: begin
                immediate = {
                    {19{instruction[31]}},
                    instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0
                };
            end

            7'b0110111,
            7'b0010111: begin
                immediate = {
                    instruction[31:12],
                    12'b0
                };
            end

            7'b1101111: begin
                immediate = {
                    {11{instruction[31]}},
                    instruction[31],
                    instruction[19:12],
                    instruction[20],
                    instruction[30:21],
                    1'b0
                };
            end

            default: begin
                immediate = 32'b0;
                illegal_format = 1'b1;
            end

        endcase
    end

endmodule
