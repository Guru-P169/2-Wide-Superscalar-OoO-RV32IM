module rv32im_axi4_read_engine_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int ID_BITS = 4,
    parameter int LEN_BITS = 8
) (
    input logic clk,
    input logic rst_n,

    input logic req_valid,
    output logic req_ready,
    input logic [ADDR_BITS-1:0] req_addr,
    input logic [LEN_BITS-1:0] req_len,
    input logic [2:0] req_size,
    input logic [ID_BITS-1:0] req_id,

    output logic resp_valid,
    input logic resp_ready,
    output logic [DATA_BITS-1:0] resp_data,
    output logic [ID_BITS-1:0] resp_id,
    output logic [1:0] resp_code,
    output logic resp_last,

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

    logic active;
    logic [ADDR_BITS-1:0] saved_addr;
    logic [LEN_BITS-1:0] saved_len;
    logic [2:0] saved_size;
    logic address_pending;
    logic [ID_BITS-1:0] saved_id;

    always_comb begin
        req_ready = !active && !address_pending;

        m_axi_arvalid = address_pending;
        m_axi_arid = saved_id;
        m_axi_araddr = saved_addr;
        m_axi_arlen = saved_len;
        m_axi_arsize = saved_size;
        m_axi_arburst = 2'b01;

        resp_valid = active && m_axi_rvalid;
        resp_data = m_axi_rdata;
        resp_id = m_axi_rid;
        resp_code = m_axi_rresp;
        resp_last = m_axi_rlast;

        m_axi_rready = active && (!resp_valid || resp_ready);
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            address_pending <= 1'b0;
            saved_id <= '0;
            saved_addr <= '0;
            saved_len <= '0;
            saved_size <= '0;
        end else begin
            if (req_valid && req_ready) begin
                saved_id <= req_id;
                saved_addr <= req_addr;
                saved_len <= req_len;
                saved_size <= req_size;
                address_pending <= 1'b1;
            end

            if (m_axi_arvalid && m_axi_arready) begin
                address_pending <= 1'b0;
                active <= 1'b1;
            end

            if (m_axi_rvalid && m_axi_rready && m_axi_rlast)
                active <= 1'b0;
        end
    end

endmodule