module rv32im_instruction_fields_g #(
    parameter int XLEN = 32,
    parameter int REG_ADDR_BITS = 5
) (
    input  logic [XLEN-1:0] instruction_0,
    input  logic [XLEN-1:0] instruction_1,

    output logic [6:0] opcode_0,
    output logic [2:0] funct3_0,
    output logic [6:0] funct7_0,
    output logic [REG_ADDR_BITS-1:0] rd_0,
    output logic [REG_ADDR_BITS-1:0] rs1_0,
    output logic [REG_ADDR_BITS-1:0] rs2_0,
    output logic [XLEN-1:0] immediate_0,

    output logic [6:0] opcode_1,
    output logic [2:0] funct3_1,
    output logic [6:0] funct7_1,
    output logic [REG_ADDR_BITS-1:0] rd_1,
    output logic [REG_ADDR_BITS-1:0] rs1_1,
    output logic [REG_ADDR_BITS-1:0] rs2_1,
    output logic [XLEN-1:0] immediate_1,

    output logic uses_rs1_0,
    output logic uses_rs2_0,
    output logic writes_rd_0,
    output logic uses_rs1_1,
    output logic uses_rs2_1,
    output logic writes_rd_1,

    output logic valid_0,
    output logic valid_1
);

    logic [31:0] imm_i_0;
    logic [31:0] imm_s_0;
    logic [31:0] imm_b_0;
    logic [31:0] imm_u_0;
    logic [31:0] imm_j_0;

    logic [31:0] imm_i_1;
    logic [31:0] imm_s_1;
    logic [31:0] imm_b_1;
    logic [31:0] imm_u_1;
    logic [31:0] imm_j_1;

    always_comb begin
        opcode_0 = instruction_0[6:0];
        funct3_0 = instruction_0[14:12];
        funct7_0 = instruction_0[31:25];
        rd_0 = instruction_0[11:7];
        rs1_0 = instruction_0[19:15];
        rs2_0 = instruction_0[24:20];

        imm_i_0 = {{20{instruction_0[31]}}, instruction_0[31:20]};
        imm_s_0 = {{20{instruction_0[31]}}, instruction_0[31:25], instruction_0[11:7]};
        imm_b_0 = {{19{instruction_0[31]}}, instruction_0[31], instruction_0[7], instruction_0[30:25], instruction_0[11:8], 1'b0};
        imm_u_0 = {instruction_0[31:12], 12'b0};
        imm_j_0 = {{11{instruction_0[31]}}, instruction_0[31], instruction_0[19:12], instruction_0[20], instruction_0[30:21], 1'b0};

        immediate_0 = '0;
        uses_rs1_0 = 1'b0;
        uses_rs2_0 = 1'b0;
        writes_rd_0 = 1'b0;
        valid_0 = 1'b1;

        case (opcode_0)
            7'b0110011: begin
                uses_rs1_0 = 1'b1;
                uses_rs2_0 = 1'b1;
                writes_rd_0 = 1'b1;
            end

            7'b0010011: begin
                immediate_0 = imm_i_0;
                uses_rs1_0 = 1'b1;
                writes_rd_0 = 1'b1;
            end

            7'b0000011: begin
                immediate_0 = imm_i_0;
                uses_rs1_0 = 1'b1;
                writes_rd_0 = 1'b1;
            end

            7'b0100011: begin
                immediate_0 = imm_s_0;
                uses_rs1_0 = 1'b1;
                uses_rs2_0 = 1'b1;
            end

            7'b1100011: begin
                immediate_0 = imm_b_0;
                uses_rs1_0 = 1'b1;
                uses_rs2_0 = 1'b1;
            end

            7'b0110111,
            7'b0010111: begin
                immediate_0 = imm_u_0;
                writes_rd_0 = 1'b1;
            end

            7'b1101111: begin
                immediate_0 = imm_j_0;
                writes_rd_0 = 1'b1;
            end

            7'b1100111: begin
                immediate_0 = imm_i_0;
                uses_rs1_0 = 1'b1;
                writes_rd_0 = 1'b1;
            end

            7'b1110011: begin
                immediate_0 = imm_i_0;
                uses_rs1_0 = instruction_0[14:12] != 3'b000;
                writes_rd_0 = instruction_0[14:12] != 3'b000;
            end

            default: begin
                valid_0 = 1'b0;
            end
        endcase

        opcode_1 = instruction_1[6:0];
        funct3_1 = instruction_1[14:12];
        funct7_1 = instruction_1[31:25];
        rd_1 = instruction_1[11:7];
        rs1_1 = instruction_1[19:15];
        rs2_1 = instruction_1[24:20];

        imm_i_1 = {{20{instruction_1[31]}}, instruction_1[31:20]};
        imm_s_1 = {{20{instruction_1[31]}}, instruction_1[31:25], instruction_1[11:7]};
        imm_b_1 = {{19{instruction_1[31]}}, instruction_1[31], instruction_1[7], instruction_1[30:25], instruction_1[11:8], 1'b0};
        imm_u_1 = {instruction_1[31:12], 12'b0};
        imm_j_1 = {{11{instruction_1[31]}}, instruction_1[31], instruction_1[19:12], instruction_1[20], instruction_1[30:21], 1'b0};

        immediate_1 = '0;
        uses_rs1_1 = 1'b0;
        uses_rs2_1 = 1'b0;
        writes_rd_1 = 1'b0;
        valid_1 = 1'b1;

        case (opcode_1)
            7'b0110011: begin
                uses_rs1_1 = 1'b1;
                uses_rs2_1 = 1'b1;
                writes_rd_1 = 1'b1;
            end

            7'b0010011: begin
                immediate_1 = imm_i_1;
                uses_rs1_1 = 1'b1;
                writes_rd_1 = 1'b1;
            end

            7'b0000011: begin
                immediate_1 = imm_i_1;
                uses_rs1_1 = 1'b1;
                writes_rd_1 = 1'b1;
            end

            7'b0100011: begin
                immediate_1 = imm_s_1;
                uses_rs1_1 = 1'b1;
                uses_rs2_1 = 1'b1;
            end

            7'b1100011: begin
                immediate_1 = imm_b_1;
                uses_rs1_1 = 1'b1;
                uses_rs2_1 = 1'b1;
            end

            7'b0110111,
            7'b0010111: begin
                immediate_1 = imm_u_1;
                writes_rd_1 = 1'b1;
            end

            7'b1101111: begin
                immediate_1 = imm_j_1;
                writes_rd_1 = 1'b1;
            end

            7'b1100111: begin
                immediate_1 = imm_i_1;
                uses_rs1_1 = 1'b1;
                writes_rd_1 = 1'b1;
            end

            7'b1110011: begin
                immediate_1 = imm_i_1;
                uses_rs1_1 = instruction_1[14:12] != 3'b000;
                writes_rd_1 = instruction_1[14:12] != 3'b000;
            end

            default: begin
                valid_1 = 1'b0;
            end
        endcase
    end

endmodule