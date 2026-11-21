module rv32im_l2_arb_cache_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 ic_mem_req_valid,
    input  logic [ADDR_BITS-1:0] ic_mem_req_addr,
    input  logic                 ic_mem_resp_ready,
    input  logic                 dc_mem_req_valid,
    input  logic                 dc_mem_req_write,
    input  logic [ADDR_BITS-1:0] dc_mem_req_addr,
    input  logic [DATA_BITS-1:0] dc_mem_req_wdata,
    input  logic [3:0]           dc_mem_req_wstrb,
    input  logic                 dc_mem_resp_ready,
    input  logic                 l2_mem_req_ready,
    input  logic                 l2_mem_resp_valid,
    input  logic [DATA_BITS-1:0] l2_mem_resp_rdata,
    input  logic                 l2_mem_resp_error,

    output logic                 ic_mem_req_ready,
    output logic                 ic_mem_resp_valid,
    output logic [DATA_BITS-1:0] ic_mem_resp_data,
    output logic                 ic_mem_resp_error,
    output logic                 dc_mem_req_ready,
    output logic                 dc_mem_resp_valid,
    output logic [DATA_BITS-1:0] dc_mem_resp_rdata,
    output logic                 dc_mem_resp_error,
    output logic                 l2_mem_req_valid,
    output logic                 l2_mem_req_write,
    output logic [ADDR_BITS-1:0] l2_mem_req_addr,
    output logic [DATA_BITS-1:0] l2_mem_req_wdata,
    output logic [3:0]           l2_mem_req_wstrb,
    output logic                 l2_mem_resp_ready
);

    logic                 l2_req_valid;
    logic                 l2_req_ready;
    logic                 l2_req_write;
    logic [ADDR_BITS-1:0] l2_req_addr;
    logic [DATA_BITS-1:0] l2_req_wdata;
    logic [3:0]           l2_req_wstrb;
    logic                 l2_resp_valid;
    logic                 l2_resp_ready;
    logic [DATA_BITS-1:0] l2_resp_rdata;
    logic                 l2_resp_error;

    rv32im_l2_arbiter_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS)
    ) u_l2_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .i_req_valid(ic_mem_req_valid),
        .i_req_ready(ic_mem_req_ready),
        .i_req_addr(ic_mem_req_addr),
        .d_req_valid(dc_mem_req_valid),
        .d_req_ready(dc_mem_req_ready),
        .d_req_write(dc_mem_req_write),
        .d_req_addr(dc_mem_req_addr),
        .d_req_wdata(dc_mem_req_wdata),
        .d_req_wstrb(dc_mem_req_wstrb),
        .l2_req_valid(l2_req_valid),
        .l2_req_ready(l2_req_ready),
        .l2_req_write(l2_req_write),
        .l2_req_addr(l2_req_addr),
        .l2_req_wdata(l2_req_wdata),
        .l2_req_wstrb(l2_req_wstrb),
        .l2_resp_valid(l2_resp_valid),
        .l2_resp_ready(l2_resp_ready),
        .l2_resp_rdata(l2_resp_rdata),
        .l2_resp_error(l2_resp_error),
        .i_resp_valid(ic_mem_resp_valid),
        .i_resp_ready(ic_mem_resp_ready),
        .i_resp_rdata(ic_mem_resp_data),
        .i_resp_error(ic_mem_resp_error),
        .d_resp_valid(dc_mem_resp_valid),
        .d_resp_ready(dc_mem_resp_ready),
        .d_resp_rdata(dc_mem_resp_rdata),
        .d_resp_error(dc_mem_resp_error)
    );

    rv32im_l2_cache_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS)
    ) u_l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(l2_req_valid),
        .req_ready(l2_req_ready),
        .req_write(l2_req_write),
        .req_addr(l2_req_addr),
        .req_wdata(l2_req_wdata),
        .req_wstrb(l2_req_wstrb),
        .resp_valid(l2_resp_valid),
        .resp_ready(l2_resp_ready),
        .resp_rdata(l2_resp_rdata),
        .resp_error(l2_resp_error),
        .mem_req_valid(l2_mem_req_valid),
        .mem_req_ready(l2_mem_req_ready),
        .mem_req_write(l2_mem_req_write),
        .mem_req_addr(l2_mem_req_addr),
        .mem_req_wdata(l2_mem_req_wdata),
        .mem_req_wstrb(l2_mem_req_wstrb),
        .mem_resp_valid(l2_mem_resp_valid),
        .mem_resp_ready(l2_mem_resp_ready),
        .mem_resp_rdata(l2_mem_resp_rdata),
        .mem_resp_error(l2_mem_resp_error)
    );

endmodule