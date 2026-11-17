
module rv32im_pc_g #(
    parameter logic [31:0] RESET_PC = 32'h00000000
) (
    input logic clk,
    input logic rst_n,

    input logic stall,
    input logic fetch_advance,

    input logic redirect_valid,
    input logic [31:0] redirect_target,

    output logic [31:0] pc
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_PC;
        end else if (redirect_valid) begin
            pc <= {redirect_target[31:2], 2'b00};
        end else if (!stall && fetch_advance) begin
            pc <= pc + 32'd8;
        end
    end

endmodule
