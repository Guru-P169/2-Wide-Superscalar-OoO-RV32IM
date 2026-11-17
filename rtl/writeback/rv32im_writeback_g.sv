module rv32im_writeback_g #(
    parameter int XLEN = 32,
    parameter int PHYS_REG_BITS = 6,
    parameter int ROB_TAG_BITS = 5
) (
    input logic valid_0,
    input logic [PHYS_REG_BITS-1:0] pdst_0,
    input logic [ROB_TAG_BITS-1:0] rob_tag_0,
    input logic [XLEN-1:0] result_0,
    input logic writes_rd_0,

    input logic valid_1,
    input logic [PHYS_REG_BITS-1:0] pdst_1,
    input logic [ROB_TAG_BITS-1:0] rob_tag_1,
    input logic [XLEN-1:0] result_1,
    input logic writes_rd_1,

    output logic prf_we_0,
    output logic [PHYS_REG_BITS-1:0] prf_waddr_0,
    output logic [XLEN-1:0] prf_wdata_0,

    output logic prf_we_1,
    output logic [PHYS_REG_BITS-1:0] prf_waddr_1,
    output logic [XLEN-1:0] prf_wdata_1,

    output logic completion_valid_0,
    output logic [ROB_TAG_BITS-1:0] completion_rob_tag_0,
    output logic [XLEN-1:0] completion_result_0,

    output logic completion_valid_1,
    output logic [ROB_TAG_BITS-1:0] completion_rob_tag_1,
    output logic [XLEN-1:0] completion_result_1
);

    always_comb begin
        prf_we_0 = valid_0 && writes_rd_0 && (pdst_0 != '0);
        prf_waddr_0 = pdst_0;
        prf_wdata_0 = result_0;

        prf_we_1 = valid_1 && writes_rd_1 && (pdst_1 != '0);
        prf_waddr_1 = pdst_1;
        prf_wdata_1 = result_1;

        completion_valid_0 = valid_0;
        completion_rob_tag_0 = rob_tag_0;
        completion_result_0 = result_0;

        completion_valid_1 = valid_1;
        completion_rob_tag_1 = rob_tag_1;
        completion_result_1 = result_1;
    end

endmodule