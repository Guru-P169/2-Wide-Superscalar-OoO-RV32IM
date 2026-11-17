
module rv32im_branch_unit_g (
    input  logic [31:0] pc,
    input  logic [31:0] immediate,
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,

    input  logic        is_branch,
    input  logic        is_jal,
    input  logic        is_jalr,
    input  logic [2:0]  branch_op,

    output logic        branch_taken,
    output logic        redirect_valid,
    output logic [31:0] branch_target,
    output logic [31:0] link_address
);

    localparam logic [2:0] BR_EQ  = 3'b000;
    localparam logic [2:0] BR_NE  = 3'b001;
    localparam logic [2:0] BR_LT  = 3'b100;
    localparam logic [2:0] BR_GE  = 3'b101;
    localparam logic [2:0] BR_LTU = 3'b110;
    localparam logic [2:0] BR_GEU = 3'b111;

    logic condition_met;
    logic [31:0] jalr_target;

    always_comb begin
        condition_met = 1'b0;
        branch_taken  = 1'b0;
        redirect_valid = 1'b0;

        branch_target = pc + immediate;
        link_address  = pc + 32'd4;

        jalr_target = (operand_a + immediate) & 32'hFFFF_FFFE;

        if (is_branch) begin
            case (branch_op)
                BR_EQ:  condition_met = (operand_a == operand_b);
                BR_NE:  condition_met = (operand_a != operand_b);
                BR_LT:  condition_met = ($signed(operand_a) < $signed(operand_b));
                BR_GE:  condition_met = ($signed(operand_a) >= $signed(operand_b));
                BR_LTU: condition_met = (operand_a < operand_b);
                BR_GEU: condition_met = (operand_a >= operand_b);
                default: condition_met = 1'b0;
            endcase

            branch_taken = condition_met;
            redirect_valid = condition_met;
        end
        else if (is_jal) begin
            branch_taken = 1'b1;
            redirect_valid = 1'b1;
        end
        else if (is_jalr) begin
            branch_taken = 1'b1;
            redirect_valid = 1'b1;
            branch_target = jalr_target;
        end
    end

endmodule
