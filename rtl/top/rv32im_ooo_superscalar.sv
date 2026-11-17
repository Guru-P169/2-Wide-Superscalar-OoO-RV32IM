module rv32im_ooo_superscalar #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int ID_BITS = 4,
    parameter int LEN_BITS = 8
) (
    input logic clk,
    input logic rst_n,

    output logic [ID_BITS-1:0] m_axi_awid,
    output logic [ADDR_BITS-1:0] m_axi_awaddr,
    output logic [LEN_BITS-1:0] m_axi_awlen,
    output logic [2:0] m_axi_awsize,
    output logic [1:0] m_axi_awburst,
    output logic m_axi_awvalid,
    input logic m_axi_awready,

    output logic [DATA_BITS-1:0] m_axi_wdata,
    output logic [DATA_BITS/8-1:0] m_axi_wstrb,
    output logic m_axi_wlast,
    output logic m_axi_wvalid,
    input logic m_axi_wready,

    input logic [ID_BITS-1:0] m_axi_bid,
    input logic [1:0] m_axi_bresp,
    input logic m_axi_bvalid,
    output logic m_axi_bready,

    output logic [ID_BITS-1:0] m_axi_arid,
    output logic [ADDR_BITS-1:0] m_axi_araddr,
    output logic [LEN_BITS-1:0] m_axi_arlen,
    output logic [2:0] m_axi_arsize,
    output logic [1:0] m_axi_arburst,
    output logic m_axi_arvalid,
    input logic m_axi_arready,

    input logic [ID_BITS-1:0] m_axi_rid,
    input logic [DATA_BITS-1:0] m_axi_rdata,
    input logic [1:0] m_axi_rresp,
    input logic m_axi_rlast,
    input logic m_axi_rvalid,
    output logic m_axi_rready
);

    logic i_req_valid;
    logic i_req_ready;
    logic [31:0] i_req_addr;
    logic i_resp_valid;
    logic i_resp_ready;
    logic [63:0] i_resp_data;
    logic [1:0] i_resp_error;

    logic d_req_valid;
    logic d_req_ready;
    logic d_req_write;
    logic [31:0] d_req_addr;
    logic [31:0] d_req_wdata;
    logic [1:0] d_req_size;
    logic d_resp_valid;
    logic d_resp_ready;
    logic [31:0] d_resp_rdata;
    logic d_resp_error;

    logic i_invalidate;

    logic core_busy;
    logic core_halted;
    logic exception_valid;
    logic [31:0] exception_pc;

    rv32im_ooo_core_g u_core (
        .clk(clk),
        .rst_n(rst_n),
        .i_req_valid(i_req_valid),
        .i_req_ready(i_req_ready),
        .i_req_addr(i_req_addr),
        .i_resp_valid(i_resp_valid),
        .i_resp_ready(i_resp_ready),
        .i_resp_data(i_resp_data),
        .i_resp_error(i_resp_error),
        .d_req_valid(d_req_valid),
        .d_req_ready(d_req_ready),
        .d_req_write(d_req_write),
        .d_req_addr(d_req_addr),
        .d_req_wdata(d_req_wdata),
        .d_req_size(d_req_size),
        .d_resp_valid(d_resp_valid),
        .d_resp_ready(d_resp_ready),
        .d_resp_rdata(d_resp_rdata),
        .d_resp_error(d_resp_error),
        .i_invalidate(i_invalidate),
        .core_busy(core_busy),
        .core_halted(core_halted),
        .exception_valid(exception_valid),
        .exception_pc(exception_pc)
    );

    rv32im_memory_subsystem_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .ID_BITS(ID_BITS),
        .LEN_BITS(LEN_BITS)
    ) u_mem (
        .clk(clk),
        .rst_n(rst_n),
        .i_req_valid(i_req_valid),
        .i_req_ready(i_req_ready),
        .i_req_addr(i_req_addr),
        .i_resp_valid(i_resp_valid),
        .i_resp_ready(i_resp_ready),
        .i_resp_data(i_resp_data),
        .i_resp_error(i_resp_error),
        .i_invalidate(i_invalidate),
        .d_req_valid(d_req_valid),
        .d_req_ready(d_req_ready),
        .d_req_write(d_req_write),
        .d_req_addr(d_req_addr),
        .d_req_wdata(d_req_wdata),
        .d_req_size(d_req_size),
        .d_resp_valid(d_resp_valid),
        .d_resp_ready(d_resp_ready),
        .d_resp_rdata(d_resp_rdata),
        .d_resp_error(d_resp_error),
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready)
    );

endmodule
