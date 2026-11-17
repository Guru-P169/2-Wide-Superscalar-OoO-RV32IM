
module rv32im_decode_stage_g (
    input logic clk,
    input logic rst_n,

    input logic flush,

    input logic in_valid0,
    input logic [31:0] in_instruction0,
    input logic [31:0] in_pc0,
    input logic [31:0] in_predicted_pc0,

    input logic in_valid1,
    input logic [31:0] in_instruction1,
    input logic [31:0] in_pc1,
    input logic [31:0] in_predicted_pc1,

    output logic in_ready0,
    output logic in_ready1,

    output logic out_valid0,
    output logic [31:0] out_instruction0,
    output logic [31:0] out_pc0,
    output logic [31:0] out_predicted_pc0,
    output logic out_illegal0,
    output logic [6:0] out_opcode0,
    output logic [2:0] out_funct3_0,
    output logic [6:0] out_funct7_0,
    output logic [4:0] out_rs1_0,
    output logic [4:0] out_rs2_0,
    output logic [4:0] out_rd0,
    output logic out_uses_rs1_0,
    output logic out_uses_rs2_0,
    output logic out_writes_rd0,
    output logic [31:0] out_immediate0,
    output logic [4:0] out_alu_op0,
    output logic [2:0] out_branch_op0,
    output logic [1:0] out_memory_size0,
    output logic out_load_unsigned0,
    output logic out_is_branch0,
    output logic out_is_jal0,
    output logic out_is_jalr0,
    output logic out_is_load0,
    output logic out_is_store0,
    output logic out_is_muldiv0,
    output logic out_is_system0,
    output logic out_is_fence0,

    output logic out_valid1,
    output logic [31:0] out_instruction1,
    output logic [31:0] out_pc1,
    output logic [31:0] out_predicted_pc1,
    output logic out_illegal1,
    output logic [6:0] out_opcode1,
    output logic [2:0] out_funct3_1,
    output logic [6:0] out_funct7_1,
    output logic [4:0] out_rs1_1,
    output logic [4:0] out_rs2_1,
    output logic [4:0] out_rd1,
    output logic out_uses_rs1_1,
    output logic out_uses_rs2_1,
    output logic out_writes_rd1,
    output logic [31:0] out_immediate1,
    output logic [4:0] out_alu_op1,
    output logic [2:0] out_branch_op1,
    output logic [1:0] out_memory_size1,
    output logic out_load_unsigned1,
    output logic out_is_branch1,
    output logic out_is_jal1,
    output logic out_is_jalr1,
    output logic out_is_load1,
    output logic out_is_store1,
    output logic out_is_muldiv1,
    output logic out_is_system1,
    output logic out_is_fence1
);

    logic decode_valid0;
    logic decode_valid1;

    logic [6:0] opcode0;
    logic [2:0] funct3_0;
    logic [6:0] funct7_0;
    logic [4:0] rs1_0;
    logic [4:0] rs2_0;
    logic [4:0] rd0;
    logic uses_rs1_0;
    logic uses_rs2_0;
    logic writes_rd0;
    logic [31:0] immediate0;
    logic [4:0] alu_op0;
    logic [2:0] branch_op0;
    logic [1:0] memory_size0;
    logic load_unsigned0;
    logic is_branch0;
    logic is_jal0;
    logic is_jalr0;
    logic is_load0;
    logic is_store0;
    logic is_muldiv0;
    logic is_system0;
    logic is_fence0;
    logic illegal0;

    logic [6:0] opcode1;
    logic [2:0] funct3_1;
    logic [6:0] funct7_1;
    logic [4:0] rs1_1;
    logic [4:0] rs2_1;
    logic [4:0] rd1;
    logic uses_rs1_1;
    logic uses_rs2_1;
    logic writes_rd1;
    logic [31:0] immediate1;
    logic [4:0] alu_op1;
    logic [2:0] branch_op1;
    logic [1:0] memory_size1;
    logic load_unsigned1;
    logic is_branch1;
    logic is_jal1;
    logic is_jalr1;
    logic is_load1;
    logic is_store1;
    logic is_muldiv1;
    logic is_system1;
    logic is_fence1;
    logic illegal1;

    rv32im_decode_g decode_lane0 (
        .instruction_valid(in_valid0 && !flush),
        .instruction(in_instruction0),
        .decode_valid(decode_valid0),
        .illegal_instruction(illegal0),
        .opcode(opcode0),
        .funct3(funct3_0),
        .funct7(funct7_0),
        .rs1(rs1_0),
        .rs2(rs2_0),
        .rd(rd0),
        .uses_rs1(uses_rs1_0),
        .uses_rs2(uses_rs2_0),
        .writes_rd(writes_rd0),
        .immediate(immediate0),
        .alu_op(alu_op0),
        .branch_op(branch_op0),
        .memory_size(memory_size0),
        .load_unsigned(load_unsigned0),
        .is_branch(is_branch0),
        .is_jal(is_jal0),
        .is_jalr(is_jalr0),
        .is_load(is_load0),
        .is_store(is_store0),
        .is_muldiv(is_muldiv0),
        .is_system(is_system0),
        .is_fence(is_fence0)
    );

    rv32im_decode_g decode_lane1 (
        .instruction_valid(in_valid1 && !flush),
        .instruction(in_instruction1),
        .decode_valid(decode_valid1),
        .illegal_instruction(illegal1),
        .opcode(opcode1),
        .funct3(funct3_1),
        .funct7(funct7_1),
        .rs1(rs1_1),
        .rs2(rs2_1),
        .rd(rd1),
        .uses_rs1(uses_rs1_1),
        .uses_rs2(uses_rs2_1),
        .writes_rd(writes_rd1),
        .immediate(immediate1),
        .alu_op(alu_op1),
        .branch_op(branch_op1),
        .memory_size(memory_size1),
        .load_unsigned(load_unsigned1),
        .is_branch(is_branch1),
        .is_jal(is_jal1),
        .is_jalr(is_jalr1),
        .is_load(is_load1),
        .is_store(is_store1),
        .is_muldiv(is_muldiv1),
        .is_system(is_system1),
        .is_fence(is_fence1)
    );

    always_comb begin
        in_ready0 = !flush;
        in_ready1 = !flush && in_valid0;

        out_valid0 = decode_valid0 && !flush;
        out_valid1 = decode_valid1 && !flush && in_valid0;

        out_instruction0 = in_instruction0;
        out_pc0 = in_pc0;
        out_predicted_pc0 = in_predicted_pc0;
        out_illegal0 = illegal0;
        out_opcode0 = opcode0;
        out_funct3_0 = funct3_0;
        out_funct7_0 = funct7_0;
        out_rs1_0 = rs1_0;
        out_rs2_0 = rs2_0;
        out_rd0 = rd0;
        out_uses_rs1_0 = uses_rs1_0;
        out_uses_rs2_0 = uses_rs2_0;
        out_writes_rd0 = writes_rd0;
        out_immediate0 = immediate0;
        out_alu_op0 = alu_op0;
        out_branch_op0 = branch_op0;
        out_memory_size0 = memory_size0;
        out_load_unsigned0 = load_unsigned0;
        out_is_branch0 = is_branch0;
        out_is_jal0 = is_jal0;
        out_is_jalr0 = is_jalr0;
        out_is_load0 = is_load0;
        out_is_store0 = is_store0;
        out_is_muldiv0 = is_muldiv0;
        out_is_system0 = is_system0;
        out_is_fence0 = is_fence0;

        out_instruction1 = in_instruction1;
        out_pc1 = in_pc1;
        out_predicted_pc1 = in_predicted_pc1;
        out_illegal1 = illegal1;
        out_opcode1 = opcode1;
        out_funct3_1 = funct3_1;
        out_funct7_1 = funct7_1;
        out_rs1_1 = rs1_1;
        out_rs2_1 = rs2_1;
        out_rd1 = rd1;
        out_uses_rs1_1 = uses_rs1_1;
        out_uses_rs2_1 = uses_rs2_1;
        out_writes_rd1 = writes_rd1;
        out_immediate1 = immediate1;
        out_alu_op1 = alu_op1;
        out_branch_op1 = branch_op1;
        out_memory_size1 = memory_size1;
        out_load_unsigned1 = load_unsigned1;
        out_is_branch1 = is_branch1;
        out_is_jal1 = is_jal1;
        out_is_jalr1 = is_jalr1;
        out_is_load1 = is_load1;
        out_is_store1 = is_store1;
        out_is_muldiv1 = is_muldiv1;
        out_is_system1 = is_system1;
        out_is_fence1 = is_fence1;
    end

endmodule
