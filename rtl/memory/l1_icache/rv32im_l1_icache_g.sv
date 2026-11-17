// L1 instruction cache - 64-bit lines (one aligned instruction pair per entry).
// One lookup per fetch packet; a hit returns both instructions in a single access.
// A miss fills the pair with two sequential word reads from the next level.
module rv32im_l1_icache_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int INDEX_BITS = 4
) (
    input logic clk,
    input logic rst_n,

    input logic req_valid,
    output logic req_ready,
    input logic [ADDR_BITS-1:0] req_addr,

    output logic resp_valid,
    input logic resp_ready,
    output logic [2*DATA_BITS-1:0] resp_inst,
    output logic [1:0] resp_error,          // per-word error: [0] = low word, [1] = high word
    input logic invalidate,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic [ADDR_BITS-1:0] mem_req_addr,

    input logic mem_resp_valid,
    output logic mem_resp_ready,
    input logic [DATA_BITS-1:0] mem_resp_data,
    input logic mem_resp_error
);

    localparam int OFFSET_BITS = 3;
    localparam int TAG_BITS = ADDR_BITS - INDEX_BITS - OFFSET_BITS;
    localparam int LINE_COUNT = 1 << INDEX_BITS;

    typedef enum logic [2:0] {
        IDLE,
        MEM_REQ0,
        MEM_WAIT0,
        MEM_REQ1,
        MEM_WAIT1,
        RESP
    } state_t;

    state_t state;

    logic [TAG_BITS-1:0] tag_array [0:LINE_COUNT-1];
    logic [2*DATA_BITS-1:0] data_array [0:LINE_COUNT-1];
    logic valid_array [0:LINE_COUNT-1];

    logic [ADDR_BITS-1:0] saved_addr;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;

    logic [2*DATA_BITS-1:0] saved_inst;
    logic [1:0] saved_error;
    logic [DATA_BITS-1:0] word0_hold;

    // lookup performed at request-accept time
    logic [INDEX_BITS-1:0] req_index;
    logic [TAG_BITS-1:0] req_tag;
    logic req_hit;
    logic accept;

    integer i;

    always_comb begin
        index = saved_addr[OFFSET_BITS +: INDEX_BITS];
        tag = saved_addr[ADDR_BITS-1 -: TAG_BITS];

        req_index = req_addr[OFFSET_BITS +: INDEX_BITS];
        req_tag = req_addr[ADDR_BITS-1 -: TAG_BITS];
        req_hit = valid_array[req_index] && (tag_array[req_index] == req_tag) && !invalidate;

        req_ready = (state == IDLE) || ((state == RESP) && resp_ready);
        accept = req_valid && req_ready;

        resp_valid = (state == RESP);
        resp_inst = saved_inst;
        resp_error = saved_error;

        mem_req_valid = (state == MEM_REQ0) || (state == MEM_REQ1);
        mem_req_addr = (state == MEM_REQ0) ? {saved_addr[ADDR_BITS-1:3], 3'b000}
                                           : {saved_addr[ADDR_BITS-1:3], 3'b100};

        mem_resp_ready = (state == MEM_WAIT0) || (state == MEM_WAIT1);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_addr <= '0;
            saved_inst <= '0;
            saved_error <= 2'b00;
            word0_hold <= '0;

            for (i = 0; i < LINE_COUNT; i++) begin
                tag_array[i] <= '0;
                data_array[i] <= '0;
                valid_array[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE, RESP: begin
                    if (state == RESP && resp_ready && !req_valid) begin
                        state <= IDLE;
                    end

                    if (accept) begin
                        saved_addr <= req_addr;
                        saved_error <= 2'b00;
                        if (req_hit) begin
                            saved_inst <= data_array[req_index];
                            state <= RESP;
                        end else begin
                            state <= MEM_REQ0;
                        end
                    end
                end

                MEM_REQ0: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= MEM_WAIT0;
                end

                MEM_WAIT0: begin
                    if (mem_resp_valid && mem_resp_ready) begin
                        word0_hold <= mem_resp_error ? '0 : mem_resp_data;
                        saved_error[0] <= mem_resp_error;
                        state <= MEM_REQ1;
                    end
                end

                MEM_REQ1: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= MEM_WAIT1;
                end

                MEM_WAIT1: begin
                    if (mem_resp_valid && mem_resp_ready) begin
                        saved_error[1] <= mem_resp_error;
                        saved_inst <= {(mem_resp_error ? '0 : mem_resp_data), word0_hold};

                        if (!saved_error[0] && !mem_resp_error) begin
                            data_array[index] <= {mem_resp_data, word0_hold};
                            tag_array[index] <= tag;
                            valid_array[index] <= 1'b1;
                        end

                        state <= RESP;
                    end
                end

                default: state <= IDLE;
            endcase

            if (invalidate) begin
                for (i = 0; i < LINE_COUNT; i++) begin
                    valid_array[i] <= 1'b0;
                end
            end
        end
    end

endmodule
