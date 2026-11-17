module rv32im_memory_subsystem_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int ID_BITS = 4,
    parameter int LEN_BITS = 8,
    parameter int LINE_BYTES = 32
) (
    input logic clk,
    input logic rst_n,

    input logic i_req_valid,
    output logic i_req_ready,
    input logic [ADDR_BITS-1:0] i_req_addr,
    output logic i_resp_valid,
    input logic i_resp_ready,
    output logic [2*DATA_BITS-1:0] i_resp_data,
    output logic [1:0] i_resp_error,
    input logic i_invalidate,

    input logic d_req_valid,
    output logic d_req_ready,
    input logic d_req_write,
    input logic [ADDR_BITS-1:0] d_req_addr,
    input logic [DATA_BITS-1:0] d_req_wdata,
    input logic [1:0] d_req_size,
    output logic d_resp_valid,
    input logic d_resp_ready,
    output logic [DATA_BITS-1:0] d_resp_rdata,
    output logic d_resp_error,

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
    output logic m_axi_rready,

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
    output logic m_axi_bready
);

    localparam int LINE_BITS = LINE_BYTES * 8;
    localparam int WORD_INDEX_BITS = $clog2(LINE_BYTES / 4);

    logic ic_mem_req_valid;
    logic ic_mem_req_ready;
    logic [ADDR_BITS-1:0] ic_mem_req_addr;
    logic ic_mem_resp_valid;
    logic ic_mem_resp_ready;
    logic [DATA_BITS-1:0] ic_mem_resp_data;
    logic ic_mem_resp_error;

    logic dc_mem_req_valid;
    logic dc_mem_req_ready;
    logic dc_mem_req_write;
    logic [ADDR_BITS-1:0] dc_mem_req_addr;
    logic [DATA_BITS-1:0] dc_mem_req_wdata;
    logic [3:0] dc_mem_req_wstrb;
    logic dc_mem_resp_valid;
    logic dc_mem_resp_ready;
    logic [DATA_BITS-1:0] dc_mem_resp_rdata;
    logic dc_mem_resp_error;

    logic l2_req_valid;
    logic l2_req_ready;
    logic l2_req_write;
    logic [ADDR_BITS-1:0] l2_req_addr;
    logic [DATA_BITS-1:0] l2_req_wdata;
    logic [3:0] l2_req_wstrb;
    logic l2_resp_valid;
    logic l2_resp_ready;
    logic [DATA_BITS-1:0] l2_resp_rdata;
    logic l2_resp_error;

    logic l2_mem_req_valid;
    logic l2_mem_req_ready;
    logic l2_mem_req_write;
    logic [ADDR_BITS-1:0] l2_mem_req_addr;
    logic [DATA_BITS-1:0] l2_mem_req_wdata;
    logic [3:0] l2_mem_req_wstrb;
    logic l2_mem_resp_valid;
    logic l2_mem_resp_ready;
    logic [DATA_BITS-1:0] l2_mem_resp_rdata;
    logic l2_mem_resp_error;

    logic rd_req_valid;
    logic rd_req_ready;
    logic [ADDR_BITS-1:0] rd_req_addr;
    logic rd_data_valid;
    logic rd_data_ready;
    logic [DATA_BITS-1:0] rd_data;
    logic rd_data_last;
    logic [ID_BITS-1:0] rd_data_id;
    logic [1:0] rd_data_resp;

    logic wr_req_valid;
    logic wr_req_ready;
    logic [ADDR_BITS-1:0] wr_req_addr;
    logic wr_data_valid;
    logic wr_data_ready;
    logic [DATA_BITS-1:0] wr_data;
    logic [3:0] wr_strb;
    logic wr_resp_valid;
    logic wr_resp_ready;
    logic [ID_BITS-1:0] wr_resp_id;
    logic [1:0] wr_resp;

    logic id_alloc_req;
    logic id_alloc_grant;
    logic [ID_BITS-1:0] id_alloc_id;
    logic id_free_valid;
    logic [ID_BITS-1:0] id_free_id;
    logic id_full;
    logic [(1<<ID_BITS)-1:0] id_active;

    logic axi_protocol_error;
    logic [7:0] axi_error_count;

    logic [DATA_BITS-1:0] adapter_word_data;
    logic [WORD_INDEX_BITS-1:0] adapter_word_index;
    logic [ADDR_BITS-1:0] adapter_line_addr;
    logic [LINE_BITS-1:0] adapter_updated_line;

    typedef enum logic [2:0] {
        B_IDLE,
        B_RD_REQ,
        B_RD_DATA,
        B_WR_REQ,
        B_WR_DATA,
        B_WR_RESP,
        B_RESP
    } bstate_t;

    bstate_t bstate;

    logic b_write;
    logic [ADDR_BITS-1:0] b_addr;
    logic [DATA_BITS-1:0] b_wdata;
    logic [3:0] b_wstrb;
    logic [ID_BITS-1:0] b_id;
    logic [DATA_BITS-1:0] b_rdata;
    logic b_error;

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

    rv32im_cache_line_adapter_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .LINE_BYTES(LINE_BYTES)
    ) u_cache_line_adapter (
        .addr(l2_mem_req_addr),
        .line_data('0),
        .word_data(adapter_word_data),
        .word_index(adapter_word_index),
        .line_addr(adapter_line_addr),
        .write_word_data(l2_mem_req_wdata),
        .write_word_strb(l2_mem_req_wstrb),
        .write_word_valid(l2_mem_req_valid && l2_mem_req_write),
        .updated_line_data(adapter_updated_line)
    );

    rv32im_axi4_id_tracker_g #(
        .ID_BITS(ID_BITS)
    ) u_axi_id_tracker (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_req(id_alloc_req),
        .alloc_grant(id_alloc_grant),
        .alloc_id(id_alloc_id),
        .free_valid(id_free_valid),
        .free_id(id_free_id),
        .full(id_full),
        .active_ids(id_active)
    );

    rv32im_axi4_master_g #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .ID_BITS(ID_BITS),
        .LEN_BITS(LEN_BITS)
    ) u_axi4_master (
        .clk(clk),
        .rst_n(rst_n),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_req_len('0),
        .rd_req_size(3'd2),
        .rd_req_id(b_id),
        .rd_data_valid(rd_data_valid),
        .rd_data_ready(rd_data_ready),
        .rd_data(rd_data),
        .rd_data_last(rd_data_last),
        .rd_data_id(rd_data_id),
        .rd_data_resp(rd_data_resp),
        .wr_req_valid(wr_req_valid),
        .wr_req_ready(wr_req_ready),
        .wr_req_addr(wr_req_addr),
        .wr_req_len('0),
        .wr_req_size(3'd2),
        .wr_req_id(b_id),
        .wr_data_valid(wr_data_valid),
        .wr_data_ready(wr_data_ready),
        .wr_data(wr_data),
        .wr_strb(wr_strb),
        .wr_data_last(1'b1),
        .wr_resp_valid(wr_resp_valid),
        .wr_resp_ready(wr_resp_ready),
        .wr_resp_id(wr_resp_id),
        .wr_resp(wr_resp),
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

    always_comb begin
        id_alloc_req = (bstate == B_IDLE) && l2_mem_req_valid;
        l2_mem_req_ready = (bstate == B_IDLE) && id_alloc_grant;

        rd_req_valid = (bstate == B_RD_REQ);
        rd_req_addr = b_addr;
        rd_data_ready = (bstate == B_RD_DATA);

        wr_req_valid = (bstate == B_WR_REQ);
        wr_req_addr = b_addr;
        wr_data_valid = (bstate == B_WR_DATA);
        wr_data = b_wdata;
        wr_strb = b_wstrb;
        wr_resp_ready = (bstate == B_WR_RESP);

        id_free_valid = 1'b0;
        id_free_id = b_id;

        if (bstate == B_RD_DATA && rd_data_valid && rd_data_last)
            id_free_valid = 1'b1;

        if (bstate == B_WR_RESP && wr_resp_valid)
            id_free_valid = 1'b1;

        l2_mem_resp_valid = (bstate == B_RESP);
        l2_mem_resp_rdata = b_rdata;
        l2_mem_resp_error = b_error;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bstate <= B_IDLE;
            b_write <= 1'b0;
            b_addr <= '0;
            b_wdata <= '0;
            b_wstrb <= '0;
            b_id <= '0;
            b_rdata <= '0;
            b_error <= 1'b0;
        end else begin
            case (bstate)
                B_IDLE: begin
                    if (l2_mem_req_valid && l2_mem_req_ready) begin
                        b_write <= l2_mem_req_write;
                        b_addr <= l2_mem_req_addr;
                        b_wdata <= l2_mem_req_wdata;
                        b_wstrb <= l2_mem_req_wstrb;
                        b_id <= id_alloc_id;
                        b_error <= 1'b0;
                        bstate <= l2_mem_req_write ? B_WR_REQ : B_RD_REQ;
                    end
                end

                B_RD_REQ: begin
                    if (rd_req_valid && rd_req_ready)
                        bstate <= B_RD_DATA;
                end

                B_RD_DATA: begin
                    if (rd_data_valid && rd_data_ready) begin
                        b_rdata <= rd_data;
                        b_error <= (rd_data_resp != 2'b00);
                        if (rd_data_last)
                            bstate <= B_RESP;
                    end
                end

                B_WR_REQ: begin
                    if (wr_req_valid && wr_req_ready)
                        bstate <= B_WR_DATA;
                end

                B_WR_DATA: begin
                    if (wr_data_valid && wr_data_ready)
                        bstate <= B_WR_RESP;
                end

                B_WR_RESP: begin
                    if (wr_resp_valid && wr_resp_ready) begin
                        b_rdata <= '0;
                        b_error <= (wr_resp != 2'b00);
                        bstate <= B_RESP;
                    end
                end

                B_RESP: begin
                    if (l2_mem_resp_valid && l2_mem_resp_ready)
                        bstate <= B_IDLE;
                end

                default: bstate <= B_IDLE;
            endcase
        end
    end

endmodule