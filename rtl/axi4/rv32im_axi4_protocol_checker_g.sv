
module rv32im_axi4_protocol_checker_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int ID_BITS = 4,
    parameter int LEN_BITS = 8,
    parameter int STRB_BITS = DATA_BITS / 8
) (
    input logic clk,
    input logic rst_n,

    input logic arvalid,
    input logic arready,
    input logic [ADDR_BITS-1:0] araddr,
    input logic [LEN_BITS-1:0] arlen,
    input logic [2:0] arsize,
    input logic [1:0] arburst,

    input logic rvalid,
    input logic rready,
    input logic [ID_BITS-1:0] rid,
    input logic [1:0] rresp,
    input logic rlast,

    input logic awvalid,
    input logic awready,
    input logic [ADDR_BITS-1:0] awaddr,
    input logic [LEN_BITS-1:0] awlen,
    input logic [2:0] awsize,
    input logic [1:0] awburst,

    input logic wvalid,
    input logic wready,
    input logic [STRB_BITS-1:0] wstrb,
    input logic wlast,

    input logic bvalid,
    input logic bready,
    input logic [ID_BITS-1:0] bid,
    input logic [1:0] bresp,

    output logic protocol_error,
    output logic [7:0] error_count
);

    logic ar_stalled;
    logic aw_stalled;
    logic w_stalled;
    logic r_stalled;
    logic b_stalled;

    logic [ADDR_BITS-1:0] araddr_saved;
    logic [LEN_BITS-1:0] arlen_saved;
    logic [2:0] arsize_saved;
    logic [1:0] arburst_saved;

    logic [ADDR_BITS-1:0] awaddr_saved;
    logic [LEN_BITS-1:0] awlen_saved;
    logic [2:0] awsize_saved;
    logic [1:0] awburst_saved;

    logic [DATA_BITS-1:0] rdata_saved;
    logic [ID_BITS-1:0] rid_saved;
    logic [1:0] rresp_saved;
    logic rlast_saved;

    logic [DATA_BITS-1:0] wdata_saved;
    logic [STRB_BITS-1:0] wstrb_saved;
    logic wlast_saved;

    logic [ID_BITS-1:0] bid_saved;
    logic [1:0] bresp_saved;

    logic [7:0] error_count_next;
    logic error_now;

    always_comb begin
        error_now = 1'b0;

        if (arvalid && (arsize > $clog2(STRB_BITS)))
            error_now = 1'b1;

        if (awvalid && (awsize > $clog2(STRB_BITS)))
            error_now = 1'b1;

        if (arvalid && (arburst == 2'b11))
            error_now = 1'b1;

        if (awvalid && (awburst == 2'b11))
            error_now = 1'b1;

        if (ar_stalled && (!arvalid ||
            araddr != araddr_saved ||
            arlen != arlen_saved ||
            arsize != arsize_saved ||
            arburst != arburst_saved))
            error_now = 1'b1;

        if (aw_stalled && (!awvalid ||
            awaddr != awaddr_saved ||
            awlen != awlen_saved ||
            awsize != awsize_saved ||
            awburst != awburst_saved))
            error_now = 1'b1;

        if (w_stalled && (!wvalid ||
            wdata_saved !== wdata_saved ||
            wstrb != wstrb_saved ||
            wlast != wlast_saved))
            error_now = 1'b1;

        if (r_stalled && (!rvalid ||
            rid != rid_saved ||
            rresp != rresp_saved ||
            rlast != rlast_saved))
            error_now = 1'b1;

        if (b_stalled && (!bvalid ||
            bid != bid_saved ||
            bresp != bresp_saved))
            error_now = 1'b1;

        error_count_next = error_count;

        if (error_now && error_count != 8'hFF)
            error_count_next = error_count + 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_stalled <= 1'b0;
            aw_stalled <= 1'b0;
            w_stalled <= 1'b0;
            r_stalled <= 1'b0;
            b_stalled <= 1'b0;

            araddr_saved <= '0;
            arlen_saved <= '0;
            arsize_saved <= '0;
            arburst_saved <= '0;

            awaddr_saved <= '0;
            awlen_saved <= '0;
            awsize_saved <= '0;
            awburst_saved <= '0;

            rdata_saved <= '0;
            rid_saved <= '0;
            rresp_saved <= '0;
            rlast_saved <= 1'b0;

            wdata_saved <= '0;
            wstrb_saved <= '0;
            wlast_saved <= 1'b0;

            bid_saved <= '0;
            bresp_saved <= '0;

            protocol_error <= 1'b0;
            error_count <= '0;
        end else begin
            ar_stalled <= arvalid && !arready;
            aw_stalled <= awvalid && !awready;
            w_stalled <= wvalid && !wready;
            r_stalled <= rvalid && !rready;
            b_stalled <= bvalid && !bready;

            if (arvalid && !arready) begin
                araddr_saved <= araddr;
                arlen_saved <= arlen;
                arsize_saved <= arsize;
                arburst_saved <= arburst;
            end

            if (awvalid && !awready) begin
                awaddr_saved <= awaddr;
                awlen_saved <= awlen;
                awsize_saved <= awsize;
                awburst_saved <= awburst;
            end

            if (wvalid && !wready) begin
                wdata_saved <= '0;
                wstrb_saved <= wstrb;
                wlast_saved <= wlast;
            end

            if (rvalid && !rready) begin
                rdata_saved <= '0;
                rid_saved <= rid;
                rresp_saved <= rresp;
                rlast_saved <= rlast;
            end

            if (bvalid && !bready) begin
                bid_saved <= bid;
                bresp_saved <= bresp;
            end

            if (error_now) begin
                protocol_error <= 1'b1;
                error_count <= error_count_next;
            end
        end
    end

endmodule
