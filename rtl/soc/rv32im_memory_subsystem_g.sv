module rv32im_memory_subsystem_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int ID_BITS = 4,
    parameter int LEN_BITS = 8,
    parameter int LINE_BYTES = 32
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                   i_req_valid,
    output logic                   i_req_ready,
    input  logic [ADDR_BITS-1:0]   i_req_addr,
    output logic                   i_resp_valid,
    input  logic                   i_resp_ready,
    output logic [2*DATA_BITS-1:0] i_resp_data,
    output logic [1:0]             i_resp_error,
    input  logic                   i_invalidate,

    input  logic                 d_req_valid,
    output logic                 d_req_ready,
    input  logic                 d_req_write,
    input  logic [ADDR_BITS-1:0] d_req_addr,
    input  logic [DATA_BITS-1:0] d_req_wdata,
    input  logic [1:0]           d_req_size,
    output logic                 d_resp_valid,
    input  logic                 d_resp_ready,
    output logic [DATA_BITS-1:0] d_resp_rdata,
    output logic                 d_resp_error,

    output logic [ID_BITS-1:0]   m_axi_arid,
    output logic [ADDR_BITS-1:0] m_axi_araddr,
    output logic [LEN_BITS-1:0]  m_axi_arlen,
    output logic [2:0]           m_axi_arsize,
    output logic [1:0]           m_axi_arburst,
    output logic                 m_axi_arvalid,
    input  logic                 m_axi_arready,

    input  logic [ID_BITS-1:0]   m_axi_rid,
    input  logic [DATA_BITS-1:0] m_axi_rdata,
    input  logic [1:0]           m_axi_rresp,
    input  logic                 m_axi_rlast,
    input  logic                 m_axi_rvalid,
    output logic                 m_axi_rready,

    output logic [ID_BITS-1:0]   m_axi_awid,
    output logic [ADDR_BITS-1:0] m_axi_awaddr,
    output logic [LEN_BITS-1:0]  m_axi_awlen,
    output logic [2:0]           m_axi_awsize,
    output logic [1:0]           m_axi_awburst,
    output logic                 m_axi_awvalid,
    input  logic                 m_axi_awready,

    output logic [DATA_BITS-1:0]   m_axi_wdata,
    output logic [DATA_BITS/8-1:0] m_axi_wstrb,
    output logic                   m_axi_wlast,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,

    input  logic [ID_BITS-1:0] m_axi_bid,
    input  logic [1:0]         m_axi_bresp,
    input  logic               m_axi_bvalid,
    output logic               m_axi_bready
);

    logic                 ic_mem_req_valid;
    logic                 ic_mem_req_ready;
    logic [ADDR_BITS-1:0] ic_mem_req_addr;
    logic                 ic_mem_resp_valid;
    logic                 ic_mem_resp_ready;
    logic [DATA_BITS-1:0] ic_mem_resp_data;
    logic                 ic_mem_resp_error;

    logic                 dc_mem_req_valid;
    logic                 dc_mem_req_ready;
    logic                 dc_mem_req_write;
    logic [ADDR_BITS-1:0] dc_mem_req_addr;
    logic [DATA_BITS-1:0] dc_mem_req_wdata;
    logic [3:0]           dc_mem_req_wstrb;
    logic                 dc_mem_resp_valid;
    logic                 dc_mem_resp_ready;
    logic [DATA_BITS-1:0] dc_mem_resp_rdata;
    logic                 dc_mem_resp_error;

    logic                 l2_mem_req_valid;
    logic                 l2_mem_req_ready;
    logic                 l2_mem_req_write;
    logic [ADDR_BITS-1:0] l2_mem_req_addr;
    logic [DATA_BITS-1:0] l2_mem_req_wdata;
    logic [3:0]           l2_mem_req_wstrb;
    logic                 l2_mem_resp_valid;
    logic                 l2_mem_resp_ready;
    logic [DATA_BITS-1:0] l2_mem_resp_rdata;
    logic                 l2_mem_resp_error;

    logic       axi_protocol_error;
    logic [7:0] axi_error_count;

    rv32im_l1_icache_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .INDEX_BITS(6)
    ) u_l1_icache (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(i_req_valid),
        .req_ready(i_req_ready),
        .req_addr(i_req_addr),
        .resp_valid(i_resp_valid),
        .resp_ready(i_resp_ready),
        .resp_inst(i_resp_data),
        .resp_error(i_resp_error),
        .invalidate(i_invalidate),
        .mem_req_valid(ic_mem_req_valid),
        .mem_req_ready(ic_mem_req_ready),
        .mem_req_addr(ic_mem_req_addr),
        .mem_resp_valid(ic_mem_resp_valid),
        .mem_resp_ready(ic_mem_resp_ready),
        .mem_resp_data(ic_mem_resp_data),
        .mem_resp_error(ic_mem_resp_error)
    );

    rv32im_l1_dcache_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS)
    ) u_l1_dcache (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(d_req_valid),
        .req_ready(d_req_ready),
        .req_write(d_req_write),
        .req_addr(d_req_addr),
        .req_wdata(d_req_wdata),
        .req_size(d_req_size),
        .resp_valid(d_resp_valid),
        .resp_ready(d_resp_ready),
        .resp_rdata(d_resp_rdata),
        .resp_error(d_resp_error),
        .mem_req_valid(dc_mem_req_valid),
        .mem_req_ready(dc_mem_req_ready),
        .mem_req_write(dc_mem_req_write),
        .mem_req_addr(dc_mem_req_addr),
        .mem_req_wdata(dc_mem_req_wdata),
        .mem_req_wstrb(dc_mem_req_wstrb),
        .mem_resp_valid(dc_mem_resp_valid),
        .mem_resp_ready(dc_mem_resp_ready),
        .mem_resp_rdata(dc_mem_resp_rdata),
        .mem_resp_error(dc_mem_resp_error)
    );

    rv32im_l2_arb_cache_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS)
    ) u_l2_arb_cache (
        .clk(clk),
        .rst_n(rst_n),
        .ic_mem_req_valid(ic_mem_req_valid),
        .ic_mem_req_addr(ic_mem_req_addr),
        .ic_mem_resp_ready(ic_mem_resp_ready),
        .dc_mem_req_valid(dc_mem_req_valid),
        .dc_mem_req_write(dc_mem_req_write),
        .dc_mem_req_addr(dc_mem_req_addr),
        .dc_mem_req_wdata(dc_mem_req_wdata),
        .dc_mem_req_wstrb(dc_mem_req_wstrb),
        .dc_mem_resp_ready(dc_mem_resp_ready),
        .l2_mem_req_ready(l2_mem_req_ready),
        .l2_mem_resp_valid(l2_mem_resp_valid),
        .l2_mem_resp_rdata(l2_mem_resp_rdata),
        .l2_mem_resp_error(l2_mem_resp_error),
        .ic_mem_req_ready(ic_mem_req_ready),
        .ic_mem_resp_valid(ic_mem_resp_valid),
        .ic_mem_resp_data(ic_mem_resp_data),
        .ic_mem_resp_error(ic_mem_resp_error),
        .dc_mem_req_ready(dc_mem_req_ready),
        .dc_mem_resp_valid(dc_mem_resp_valid),
        .dc_mem_resp_rdata(dc_mem_resp_rdata),
        .dc_mem_resp_error(dc_mem_resp_error),
        .l2_mem_req_valid(l2_mem_req_valid),
        .l2_mem_req_write(l2_mem_req_write),
        .l2_mem_req_addr(l2_mem_req_addr),
        .l2_mem_req_wdata(l2_mem_req_wdata),
        .l2_mem_req_wstrb(l2_mem_req_wstrb),
        .l2_mem_resp_ready(l2_mem_resp_ready)
    );

    rv32im_axi4_bridge_idt_master_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .ID_BITS(ID_BITS),
        .LEN_BITS(LEN_BITS)
    ) u_axi4_bridge_idt_master (
        .clk              (clk),
        .rst_n            (rst_n),
        .l2_mem_req_valid (l2_mem_req_valid),
        .l2_mem_req_write (l2_mem_req_write),
        .l2_mem_req_addr  (l2_mem_req_addr),
        .l2_mem_req_wdata (l2_mem_req_wdata),
        .l2_mem_req_wstrb (l2_mem_req_wstrb),
        .l2_mem_resp_ready(l2_mem_resp_ready),
        .m_axi_arready    (m_axi_arready),
        .m_axi_rid        (m_axi_rid),
        .m_axi_rdata      (m_axi_rdata),
        .m_axi_rresp      (m_axi_rresp),
        .m_axi_rlast      (m_axi_rlast),
        .m_axi_rvalid     (m_axi_rvalid),
        .m_axi_awready    (m_axi_awready),
        .m_axi_wready     (m_axi_wready),
        .m_axi_bid        (m_axi_bid),
        .m_axi_bresp      (m_axi_bresp),
        .m_axi_bvalid     (m_axi_bvalid),
        .l2_mem_req_ready (l2_mem_req_ready),
        .l2_mem_resp_valid(l2_mem_resp_valid),
        .l2_mem_resp_rdata(l2_mem_resp_rdata),
        .l2_mem_resp_error(l2_mem_resp_error),
        .m_axi_arid       (m_axi_arid),
        .m_axi_araddr     (m_axi_araddr),
        .m_axi_arlen      (m_axi_arlen),
        .m_axi_arsize     (m_axi_arsize),
        .m_axi_arburst    (m_axi_arburst),
        .m_axi_arvalid    (m_axi_arvalid),
        .m_axi_rready     (m_axi_rready),
        .m_axi_awid       (m_axi_awid),
        .m_axi_awaddr     (m_axi_awaddr),
        .m_axi_awlen      (m_axi_awlen),
        .m_axi_awsize     (m_axi_awsize),
        .m_axi_awburst    (m_axi_awburst),
        .m_axi_awvalid    (m_axi_awvalid),
        .m_axi_wdata      (m_axi_wdata),
        .m_axi_wstrb      (m_axi_wstrb),
        .m_axi_wlast      (m_axi_wlast),
        .m_axi_wvalid     (m_axi_wvalid),
        .m_axi_bready     (m_axi_bready)
    );

    rv32im_axi4_protocol_checker_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .ID_BITS(ID_BITS),
        .LEN_BITS(LEN_BITS)
    ) u_axi4_protocol_checker (
        .clk(clk),
        .rst_n(rst_n),
        .arvalid(m_axi_arvalid),
        .arready(m_axi_arready),
        .araddr(m_axi_araddr),
        .arlen(m_axi_arlen),
        .arsize(m_axi_arsize),
        .arburst(m_axi_arburst),
        .rvalid(m_axi_rvalid),
        .rready(m_axi_rready),
        .rid(m_axi_rid),
        .rresp(m_axi_rresp),
        .rlast(m_axi_rlast),
        .awvalid(m_axi_awvalid),
        .awready(m_axi_awready),
        .awaddr(m_axi_awaddr),
        .awlen(m_axi_awlen),
        .awsize(m_axi_awsize),
        .awburst(m_axi_awburst),
        .wvalid(m_axi_wvalid),
        .wready(m_axi_wready),
        .wstrb(m_axi_wstrb),
        .wlast(m_axi_wlast),
        .bvalid(m_axi_bvalid),
        .bready(m_axi_bready),
        .bid(m_axi_bid),
        .bresp(m_axi_bresp),
        .protocol_error(axi_protocol_error),
        .error_count(axi_error_count)
    );

endmodule