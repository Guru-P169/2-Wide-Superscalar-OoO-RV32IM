
module rv32im_decode_g (
    input logic instruction_valid,
    input logic [31:0] instruction,

    output logic decode_valid,
    output logic illegal_instruction,

    output logic [6:0] opcode,
    output logic [2:0] funct3,
    output logic [6:0] funct7,

    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd,

    output logic uses_rs1,
    output logic uses_rs2,
    output logic writes_rd,

    output logic [31:0] immediate,

    output logic [4:0] alu_op,
    output logic [2:0] branch_op,
    output logic [1:0] memory_size,
    output logic load_unsigned,

    output logic is_branch,
    output logic is_jal,
    output logic is_jalr,
    output logic is_load,
    output logic is_store,
    output logic is_muldiv,
    output logic is_system,
    output logic is_fence
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

    localparam logic [2:0] BR_EQ  = 3'd0;
    localparam logic [2:0] BR_NE  = 3'd1;
    localparam logic [2:0] BR_LT  = 3'd4;
    localparam logic [2:0] BR_GE  = 3'd5;
    localparam logic [2:0] BR_LTU = 3'd6;
    localparam logic [2:0] BR_GEU = 3'd7;

    localparam logic [6:0] OPCODE_LOAD    = 7'b0000011;
    localparam logic [6:0] OPCODE_OP_IMM  = 7'b0010011;
    localparam logic [6:0] OPCODE_AUIPC   = 7'b0010111;
    localparam logic [6:0] OPCODE_STORE   = 7'b0100011;
    localparam logic [6:0] OPCODE_OP      = 7'b0110011;
    localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
    localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR    = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
    localparam logic [6:0] OPCODE_SYSTEM  = 7'b1110011;
    localparam logic [6:0] OPCODE_MISC_MEM = 7'b0001111;

    logic [31:0] immediate_i;
    logic [31:0] immediate_s;
    logic [31:0] immediate_b;
    logic [31:0] immediate_u;
    logic [31:0] immediate_j;

    always_comb begin
        opcode = instruction[6:0];
        rd = instruction[11:7];
        funct3 = instruction[14:12];
        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        funct7 = instruction[31:25];

        immediate_i = {{20{instruction[31]}}, instruction[31:20]};
        immediate_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        immediate_b = {{19{instruction[31]}}, instruction[31], instruction[7],
                       instruction[30:25], instruction[11:8], 1'b0};
        immediate_u = {instruction[31:12], 12'b0};
        immediate_j = {{11{instruction[31]}}, instruction[31],
                       instruction[19:12], instruction[20],
                       instruction[30:21], 1'b0};
    end

    always_comb begin
        decode_valid = instruction_valid;
        illegal_instruction = 1'b0;

        uses_rs1 = 1'b0;
        uses_rs2 = 1'b0;
        writes_rd = 1'b0;

        immediate = 32'b0;
        alu_op = ALU_ADD;
        branch_op = funct3;
        memory_size = 2'b10;
        load_unsigned = 1'b0;

        is_branch = 1'b0;
        is_jal = 1'b0;
        is_jalr = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        is_muldiv = 1'b0;
        is_system = 1'b0;
        is_fence = 1'b0;

        if (instruction_valid) begin
            case (opcode)

                OPCODE_OP_IMM: begin
                    uses_rs1 = 1'b1;
                    writes_rd = 1'b1;
                    immediate = immediate_i;

                    case (funct3)
                        3'b000: alu_op = ALU_ADD;
                        3'b010: alu_op = ALU_SLT;
                        3'b011: alu_op = ALU_SLTU;
                        3'b100: alu_op = ALU_XOR;
                        3'b110: alu_op = ALU_OR;
                        3'b111: alu_op = ALU_AND;

                        3'b001: begin
                            alu_op = ALU_SLL;
                            if (funct7 != 7'b0000000)
                                illegal_instruction = 1'b1;
                        end

                        3'b101: begin
                            if (funct7 == 7'b0000000)
                                alu_op = ALU_SRL;
                            else if (funct7 == 7'b0100000)
                                alu_op = ALU_SRA;
                            else
                                illegal_instruction = 1'b1;
                        end

                        default: illegal_instruction = 1'b1;
                    endcase
                end

                OPCODE_OP: begin
                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;
                    writes_rd = 1'b1;

                    if (funct7 == 7'b0000001) begin
                        is_muldiv = 1'b1;
                    end else begin
                        case (funct3)
                            3'b000: begin
                                if (funct7 == 7'b0000000)
                                    alu_op = ALU_ADD;
                                else if (funct7 == 7'b0100000)
                                    alu_op = ALU_SUB;
                                else
                                    illegal_instruction = 1'b1;
                            end

                            3'b001: begin
                                alu_op = ALU_SLL;
                                if (funct7 != 7'b0000000)
                                    illegal_instruction = 1'b1;
                            end

                            3'b010: begin
                                alu_op = ALU_SLT;
                                if (funct7 != 7'b0000000)
                                    illegal_instruction = 1'b1;
                            end

                            3'b011: begin
                                alu_op = ALU_SLTU;
                                if (funct7 != 7'b0000000)
                                    illegal_instruction = 1'b1;
                            end

                            3'b100: begin
                                alu_op = ALU_XOR;
                                if (funct7 != 7'b0000000)
                                    illegal_instruction = 1'b1;
                            end

                            3'b101: begin
                                if (funct7 == 7'b0000000)
                                    alu_op = ALU_SRL;
                                else if (funct7 == 7'b0100000)
                                    alu_op = ALU_SRA;
                                else
                                    illegal_instruction = 1'b1;
                            end

                            3'b110: begin
                                alu_op = ALU_OR;
                                if (funct7 != 7'b0000000)
                                    illegal_instruction = 1'b1;
                            end

                            3'b111: begin
                                alu_op = ALU_AND;
                                if (funct7 != 7'b0000000)
                                    illegal_instruction = 1'b1;
                            end

                            default: illegal_instruction = 1'b1;
                        endcase
                    end
                end

                OPCODE_LUI: begin
                    writes_rd = 1'b1;
                    immediate = immediate_u;
                    alu_op = ALU_COPY_B;
                end

                OPCODE_AUIPC: begin
                    writes_rd = 1'b1;
                    immediate = immediate_u;
                    alu_op = ALU_ADD;
                end

                OPCODE_LOAD: begin
                    uses_rs1 = 1'b1;
                    writes_rd = 1'b1;
                    immediate = immediate_i;
                    is_load = 1'b1;
                    alu_op = ALU_ADD;

                    case (funct3)
                        3'b000: begin
                            memory_size = 2'b00;
                            load_unsigned = 1'b0;
                        end
                        3'b001: begin
                            memory_size = 2'b01;
                            load_unsigned = 1'b0;
                        end
                        3'b010: begin
                            memory_size = 2'b10;
                            load_unsigned = 1'b0;
                        end
                        3'b100: begin
                            memory_size = 2'b00;
                            load_unsigned = 1'b1;
                        end
                        3'b101: begin
                            memory_size = 2'b01;
                            load_unsigned = 1'b1;
                        end
                        default: illegal_instruction = 1'b1;
                    endcase
                end

                OPCODE_STORE: begin
                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;
                    immediate = immediate_s;
                    is_store = 1'b1;
                    alu_op = ALU_ADD;

                    case (funct3)
                        3'b000: memory_size = 2'b00;
                        3'b001: memory_size = 2'b01;
                        3'b010: memory_size = 2'b10;
                        default: illegal_instruction = 1'b1;
                    endcase
                end

                OPCODE_BRANCH: begin
                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;
                    immediate = immediate_b;
                    is_branch = 1'b1;

                    case (funct3)
                        3'b000: branch_op = BR_EQ;
                        3'b001: branch_op = BR_NE;
                        3'b100: branch_op = BR_LT;
                        3'b101: branch_op = BR_GE;
                        3'b110: branch_op = BR_LTU;
                        3'b111: branch_op = BR_GEU;
                        default: illegal_instruction = 1'b1;
                    endcase
                end

                OPCODE_JAL: begin
                    writes_rd = 1'b1;
                    immediate = immediate_j;
                    is_jal = 1'b1;
                end

                OPCODE_JALR: begin
                    uses_rs1 = 1'b1;
                    writes_rd = 1'b1;
                    immediate = immediate_i;
                    is_jalr = 1'b1;

                    if (funct3 != 3'b000)
                        illegal_instruction = 1'b1;
                end

                OPCODE_MISC_MEM: begin
                    if (funct3 == 3'b000) begin
                        is_fence = 1'b1;
                    end else if (funct3 == 3'b001) begin
                        is_fence = 1'b1;
                    end else begin
                        illegal_instruction = 1'b1;
                    end
                end

                OPCODE_SYSTEM: begin
                    is_system = 1'b1;

                    if (funct3 == 3'b000) begin
                        if ((instruction[31:20] == 12'h000) ||
                            (instruction[31:20] == 12'h001) ||
                            (instruction[31:20] == 12'h105) ||
                            (instruction[31:20] == 12'h302)) begin
                            uses_rs1 = 1'b0;
                            uses_rs2 = 1'b0;
                            writes_rd = 1'b0;
                        end else begin
                            illegal_instruction = 1'b1;
                        end
                    end else begin
                        uses_rs1 = !funct3[2];
                        writes_rd = 1'b1;
                        immediate = {27'b0, instruction[19:15]};

                        case (funct3)
                            3'b001, 3'b010, 3'b011,
                            3'b101, 3'b110, 3'b111: begin
                                if (funct3[2])
                                    uses_rs1 = 1'b0;
                            end
                            default: illegal_instruction = 1'b1;
                        endcase
                    end
                end

                default: begin
                    illegal_instruction = 1'b1;
                end

            endcase
        end
    end

endmodule
