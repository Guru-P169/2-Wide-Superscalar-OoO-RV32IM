
module rv32im_axi4_write_engine_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int ID_BITS = 4,
    parameter int LEN_BITS = 8,
    parameter int STRB_BITS = DATA_BITS / 8
) (
    input logic clk,
    input logic rst_n,

    input logic req_valid,
    output logic req_ready,
    input logic [ADDR_BITS-1:0] req_addr,
    input logic [LEN_BITS-1:0] req_len,
    input logic [2:0] req_size,
    input logic [ID_BITS-1:0] req_id,

    input logic data_valid,
    output logic data_ready,
    input logic [DATA_BITS-1:0] data,
    input logic [STRB_BITS-1:0] strb,

    output logic resp_valid,
    input logic resp_ready,
    output logic [ID_BITS-1:0] resp_id,
    output logic [1:0] resp_code,

    output logic [ID_BITS-1:0] m_axi_awid,
    output logic [ADDR_BITS-1:0] m_axi_awaddr,
    output logic [LEN_BITS-1:0] m_axi_awlen,
    output logic [2:0] m_axi_awsize,
    output logic [1:0] m_axi_awburst,
    output logic m_axi_awvalid,
    input logic m_axi_awready,

    output logic [DATA_BITS-1:0] m_axi_wdata,
    output logic [STRB_BITS-1:0] m_axi_wstrb,
    output logic m_axi_wlast,
    output logic m_axi_wvalid,
    input logic m_axi_wready,

    input logic [ID_BITS-1:0] m_axi_bid,
    input logic [1:0] m_axi_bresp,
    input logic m_axi_bvalid,
    output logic m_axi_bready
);

    typedef enum logic [1:0] {
        IDLE,
        ADDRESS,
        WRITE_DATA,
        RESPONSE
    } state_t;

    state_t state;

    logic [ADDR_BITS-1:0] saved_addr;
    logic [LEN_BITS-1:0] saved_len;
    logic [LEN_BITS-1:0] beat_count;
    logic [2:0] saved_size;
    logic [ID_BITS-1:0] saved_id;

    always_comb begin
        req_ready = state == IDLE;

        m_axi_awid = saved_id;
        m_axi_awaddr = saved_addr;
        m_axi_awlen = saved_len;
        m_axi_awsize = saved_size;
        m_axi_awburst = 2'b01;
        m_axi_awvalid = state == ADDRESS;

        data_ready = state == WRITE_DATA && m_axi_wready;
        m_axi_wvalid = state == WRITE_DATA && data_valid;
        m_axi_wdata = data;
        m_axi_wstrb = strb;
        m_axi_wlast = beat_count == saved_len;

        m_axi_bready = state == RESPONSE && resp_ready;
        resp_valid = state == RESPONSE && m_axi_bvalid;
        resp_id = m_axi_bid;
        resp_code = m_axi_bresp;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_addr <= '0;
            saved_len <= '0;
            beat_count <= '0;
            saved_size <= '0;
            saved_id <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (req_valid && req_ready) begin
                        saved_addr <= req_addr;
                        saved_len <= req_len;
                        saved_size <= req_size;
                        saved_id <= req_id;
                        beat_count <= '0;
                        state <= ADDRESS;
                    end
                end

                ADDRESS: begin
                    if (m_axi_awvalid && m_axi_awready)
                        state <= WRITE_DATA;
                end

                WRITE_DATA: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        if (beat_count == saved_len)
                            state <= RESPONSE;
                        else
                            beat_count <= beat_count + 1'b1;
                    end
                end

                RESPONSE: begin
                    if (m_axi_bvalid && m_axi_bready)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
