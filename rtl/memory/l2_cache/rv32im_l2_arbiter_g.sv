module rv32im_l2_arbiter_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32
) (
    input logic clk,
    input logic rst_n,

    input logic i_req_valid,
    output logic i_req_ready,
    input logic [ADDR_BITS-1:0] i_req_addr,

    input logic d_req_valid,
    output logic d_req_ready,
    input logic d_req_write,
    input logic [ADDR_BITS-1:0] d_req_addr,
    input logic [DATA_BITS-1:0] d_req_wdata,
    input logic [3:0] d_req_wstrb,

    output logic l2_req_valid,
    input logic l2_req_ready,
    output logic l2_req_write,
    output logic [ADDR_BITS-1:0] l2_req_addr,
    output logic [DATA_BITS-1:0] l2_req_wdata,
    output logic [3:0] l2_req_wstrb,

    input logic l2_resp_valid,
    output logic l2_resp_ready,
    input logic [DATA_BITS-1:0] l2_resp_rdata,
    input logic l2_resp_error,

    output logic i_resp_valid,
    input logic i_resp_ready,
    output logic [DATA_BITS-1:0] i_resp_rdata,
    output logic i_resp_error,

    output logic d_resp_valid,
    input logic d_resp_ready,
    output logic [DATA_BITS-1:0] d_resp_rdata,
    output logic d_resp_error
);

    typedef enum logic [1:0] {
        IDLE,
        SEND_REQ,
        WAIT_RESP,
        SEND_RESP
    } state_t;

    state_t state;

    logic prefer_data;
    logic selected_data;
    logic selected_data_q;
    logic saved_data_owner;

    logic [DATA_BITS-1:0] saved_rdata;
    logic saved_error;

    always_comb begin
        i_req_ready = 1'b0;
        d_req_ready = 1'b0;

        l2_req_valid = 1'b0;
        l2_req_write = 1'b0;
        l2_req_addr = '0;
        l2_req_wdata = '0;
        l2_req_wstrb = '0;

        l2_resp_ready = 1'b0;

        i_resp_valid = 1'b0;
        i_resp_rdata = saved_rdata;
        i_resp_error = saved_error;

        d_resp_valid = 1'b0;
        d_resp_rdata = saved_rdata;
        d_resp_error = saved_error;

        selected_data = prefer_data;

        case (state)
            IDLE: begin
                if (i_req_valid && d_req_valid) begin
                    selected_data = prefer_data;
                end else if (d_req_valid) begin
                    selected_data = 1'b1;
                end else begin
                    selected_data = 1'b0;
                end
            end

            SEND_REQ: begin
                l2_req_valid = selected_data_q ? d_req_valid : i_req_valid;
                l2_req_write = selected_data_q ? d_req_write : 1'b0;
                l2_req_addr = selected_data_q ? d_req_addr : i_req_addr;
                l2_req_wdata = selected_data_q ? d_req_wdata : '0;
                l2_req_wstrb = selected_data_q ? d_req_wstrb : '0;

                if (selected_data_q) begin
                    d_req_ready = l2_req_ready;
                end else begin
                    i_req_ready = l2_req_ready;
                end
            end

            WAIT_RESP: begin
                l2_resp_ready = 1'b1;
            end

            SEND_RESP: begin
                if (saved_data_owner) begin
                    d_resp_valid = 1'b1;
                end else begin
                    i_resp_valid = 1'b1;
                end
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prefer_data <= 1'b1;
            selected_data_q <= 1'b0;
            saved_data_owner <= 1'b0;
            saved_rdata <= '0;
            saved_error <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (i_req_valid || d_req_valid) begin
                        if (i_req_valid && d_req_valid) begin
                            selected_data_q <= prefer_data;
                        end else begin
                            selected_data_q <= d_req_valid;
                        end
                        state <= SEND_REQ;
                    end
                end

                SEND_REQ: begin
                    if (l2_req_valid && l2_req_ready) begin
                        saved_data_owner <= selected_data_q;
                        prefer_data <= !selected_data_q;
                        state <= WAIT_RESP;
                    end
                end

                WAIT_RESP: begin
                    if (l2_resp_valid && l2_resp_ready) begin
                        saved_rdata <= l2_resp_rdata;
                        saved_error <= l2_resp_error;
                        state <= SEND_RESP;
                    end
                end

                SEND_RESP: begin
                    if ((saved_data_owner && d_resp_ready) ||
                        (!saved_data_owner && i_resp_ready)) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule