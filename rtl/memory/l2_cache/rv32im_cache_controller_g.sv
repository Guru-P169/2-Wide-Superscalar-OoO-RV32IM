
module rv32im_cache_controller_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int INDEX_BITS = 6,
    parameter int TAG_BITS = ADDR_BITS - INDEX_BITS - 2
) (
    input logic clk,
    input logic rst_n,

    input logic req_valid,
    output logic req_ready,
    input logic req_write,
    input logic [ADDR_BITS-1:0] req_addr,
    input logic [DATA_BITS-1:0] req_wdata,
    input logic [3:0] req_wstrb,

    output logic resp_valid,
    input logic resp_ready,
    output logic [DATA_BITS-1:0] resp_rdata,
    output logic resp_error,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic mem_req_write,
    output logic [ADDR_BITS-1:0] mem_req_addr,
    output logic [DATA_BITS-1:0] mem_req_wdata,
    output logic [3:0] mem_req_wstrb,

    input logic mem_resp_valid,
    output logic mem_resp_ready,
    input logic [DATA_BITS-1:0] mem_resp_rdata,
    input logic mem_resp_error
);

    localparam int OFFSET_BITS = 2;
    localparam int LINE_COUNT = 1 << INDEX_BITS;

    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        MEM_REQ,
        MEM_WAIT,
        RESP
    } state_t;

    state_t state;

    logic [TAG_BITS-1:0] tag_array [0:LINE_COUNT-1];
    logic [DATA_BITS-1:0] data_array [0:LINE_COUNT-1];
    logic valid_array [0:LINE_COUNT-1];

    logic [ADDR_BITS-1:0] saved_addr;
    logic saved_write;
    logic [DATA_BITS-1:0] saved_wdata;
    logic [3:0] saved_wstrb;
    logic [DATA_BITS-1:0] saved_rdata;
    logic saved_error;

    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    logic hit;
    logic [DATA_BITS-1:0] merged_wdata;

    integer i;

    always_comb begin
        index = saved_addr[OFFSET_BITS +: INDEX_BITS];
        tag = saved_addr[ADDR_BITS-1 -: TAG_BITS];

        hit = valid_array[index] && (tag_array[index] == tag);

        merged_wdata = data_array[index];

        for (int b = 0; b < 4; b++) begin
            if (saved_wstrb[b]) begin
                merged_wdata[b*8 +: 8] = saved_wdata[b*8 +: 8];
            end
        end

        req_ready = (state == IDLE);

        resp_valid = (state == RESP);
        resp_rdata = saved_rdata;
        resp_error = saved_error;

        mem_req_valid = (state == MEM_REQ);
        mem_req_write = saved_write;
        mem_req_addr = {saved_addr[ADDR_BITS-1:2], 2'b00};
        mem_req_wdata = saved_wdata;
        mem_req_wstrb = saved_wstrb;

        mem_resp_ready = (state == MEM_WAIT);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_addr <= '0;
            saved_write <= 1'b0;
            saved_wdata <= '0;
            saved_wstrb <= '0;
            saved_rdata <= '0;
            saved_error <= 1'b0;

            for (i = 0; i < LINE_COUNT; i++) begin
                tag_array[i] <= '0;
                data_array[i] <= '0;
                valid_array[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (req_valid && req_ready) begin
                        saved_addr <= req_addr;
                        saved_write <= req_write;
                        saved_wdata <= req_wdata;
                        saved_wstrb <= req_wstrb;
                        saved_error <= 1'b0;
                        state <= LOOKUP;
                    end
                end

                LOOKUP: begin
                    if (hit && !saved_write) begin
                        saved_rdata <= data_array[index];
                        state <= RESP;
                    end else if (hit && saved_write) begin
                        data_array[index] <= merged_wdata;
                        state <= MEM_REQ;
                    end else begin
                        state <= MEM_REQ;
                    end
                end

                MEM_REQ: begin
                    if (mem_req_valid && mem_req_ready) begin
                        state <= MEM_WAIT;
                    end
                end

                MEM_WAIT: begin
                    if (mem_resp_valid && mem_resp_ready) begin
                        saved_error <= mem_resp_error;
                        saved_rdata <= mem_resp_rdata;

                        if (!mem_resp_error && !saved_write) begin
                            data_array[index] <= mem_resp_rdata;
                            tag_array[index] <= tag;
                            valid_array[index] <= 1'b1;
                        end

                        state <= RESP;
                    end
                end

                RESP: begin
                    if (resp_valid && resp_ready) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
