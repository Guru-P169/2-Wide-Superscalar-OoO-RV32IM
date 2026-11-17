module rv32im_muldiv_unit_g (
    input  logic clk,
    input  logic rst_n,

    input  logic req_valid,
    output logic req_ready,
    input  logic [2:0]  req_funct3,
    input  logic [31:0] req_operand_a,
    input  logic [31:0] req_operand_b,

    output logic rsp_valid,
    input  logic rsp_ready,
    output logic [31:0] rsp_result
);

    localparam logic [2:0] M_MUL = 3'b000;
    localparam logic [2:0] M_MULH = 3'b001;
    localparam logic [2:0] M_MULHSU = 3'b010;
    localparam logic [2:0] M_MULHU  = 3'b011;
    localparam logic [2:0] M_DIV    = 3'b100;
    localparam logic [2:0] M_DIVU   = 3'b101;
    localparam logic [2:0] M_REM    = 3'b110;
    localparam logic [2:0] M_REMU   = 3'b111;

    logic [63:0] product_ss;
    logic [63:0] product_su;
    logic [63:0] product_uu;

    logic signed [31:0] signed_a;
    logic signed [31:0] signed_b;
    logic signed [63:0] signed_product;
    logic signed [63:0] signed_unsigned_product;

    logic [31:0] calculated_result;
    logic [31:0] divide_result;
    logic [31:0] remainder_result;

    logic signed [31:0] signed_quotient;
    logic signed [31:0] signed_remainder;

    logic output_slot_available;

    always_comb begin
        signed_a = $signed(req_operand_a);
        signed_b = $signed(req_operand_b);

        signed_product = signed_a * signed_b;

        signed_unsigned_product =
            $signed(req_operand_a) * $signed({1'b0, req_operand_b});

        product_ss = signed_product;
        product_su = signed_unsigned_product;
        product_uu = req_operand_a * req_operand_b;

        divide_result = '0;
        remainder_result = '0;
        signed_quotient = '0;
        signed_remainder = '0;

        if (req_operand_b == 32'b0) begin
            divide_result = 32'hFFFF_FFFF;
            remainder_result = req_operand_a;
        end
        else begin
            divide_result = req_operand_a / req_operand_b;
            remainder_result = req_operand_a % req_operand_b;
            if (!((req_operand_a == 32'h8000_0000) &&
                  (req_operand_b == 32'hFFFF_FFFF))) begin
                signed_quotient = signed_a / signed_b;
                signed_remainder = signed_a % signed_b;
            end
        end

        calculated_result = '0;

        case (req_funct3)
            M_MUL: begin
                calculated_result = product_uu[31:0];
            end

            M_MULH: begin
                calculated_result = product_ss[63:32];
            end

            M_MULHSU: begin
                calculated_result = product_su[63:32];
            end

            M_MULHU: begin
                calculated_result = product_uu[63:32];
            end

            M_DIV: begin
                if (req_operand_b == 32'b0)
                    calculated_result = 32'hFFFF_FFFF;
                else if ((req_operand_a == 32'h8000_0000) &&
                         (req_operand_b == 32'hFFFF_FFFF))
                    calculated_result = 32'h8000_0000;
                else
                    calculated_result = signed_quotient;
            end

            M_DIVU: begin
                calculated_result = divide_result;
            end

            M_REM: begin
                if (req_operand_b == 32'b0)
                    calculated_result = req_operand_a;
                else if ((req_operand_a == 32'h8000_0000) &&
                         (req_operand_b == 32'hFFFF_FFFF))
                    calculated_result = 32'b0;
                else
                    calculated_result = signed_remainder;
            end

            M_REMU: begin
                calculated_result = remainder_result;
            end

            default: begin
                calculated_result = 32'b0;
            end
        endcase
    end

    assign output_slot_available = !rsp_valid || rsp_ready;
    assign req_ready = output_slot_available;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid  <= 1'b0;
            rsp_result <= 32'b0;
        end
        else if (output_slot_available) begin
            rsp_valid <= req_valid;

            if (req_valid)
                rsp_result <= calculated_result;
        end
    end

endmodule