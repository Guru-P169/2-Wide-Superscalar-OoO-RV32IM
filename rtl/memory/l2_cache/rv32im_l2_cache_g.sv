module rv32im_l2_cache_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int INDEX_BITS = 5,
    parameter int WORD_BITS = 3
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
    localparam int LINE_WORDS = 1 << WORD_BITS;
    localparam int TAG_BITS = ADDR_BITS - INDEX_BITS - WORD_BITS - OFFSET_BITS;
    localparam int LINE_COUNT = 1 << INDEX_BITS;

    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        MEM_REQ,
        MEM_WAIT,
        RESP,
        WR_REQ,
        WR_WAIT
    } state_t;

    state_t state;

    logic [TAG_BITS-1:0] tag_array [0:LINE_COUNT-1];
    logic [DATA_BITS-1:0] data_array [0:LINE_COUNT*LINE_WORDS-1];
    logic valid_array [0:LINE_COUNT-1];

    logic [ADDR_BITS-1:0] saved_addr;
    logic saved_write;
    logic [DATA_BITS-1:0] saved_wdata;
    logic [3:0] saved_wstrb;
    logic [DATA_BITS-1:0] saved_rdata;
    logic saved_error;
    logic [WORD_BITS-1:0] rf_cnt;

    logic [INDEX_BITS-1:0] index;
    logic [WORD_BITS-1:0] widx;
    logic [TAG_BITS-1:0] tag;
    logic hit;
    logic [DATA_BITS-1:0] cur_word;
    logic [DATA_BITS-1:0] merged_wdata;
    logic [ADDR_BITS-1:0] line_base;

    integer i;

    always_comb begin
        widx = saved_addr[OFFSET_BITS +: WORD_BITS];
        index = saved_addr[OFFSET_BITS + WORD_BITS +: INDEX_BITS];
        tag = saved_addr[ADDR_BITS-1 -: TAG_BITS];

        hit = valid_array[index] && (tag_array[index] == tag);

        cur_word = data_array[{index, widx}];
        merged_wdata = cur_word;

        for (int b = 0; b < 4; b++) begin
            if (saved_wstrb[b]) begin
                merged_wdata[b*8 +: 8] = saved_wdata[b*8 +: 8];
            end
        end

        line_base = {saved_addr[ADDR_BITS-1:OFFSET_BITS+WORD_BITS], {(OFFSET_BITS+WORD_BITS){1'b0}}};

        req_ready = (state == IDLE);

        resp_valid = (state == RESP);
        resp_rdata = saved_rdata;
        resp_error = saved_error;

        mem_req_valid = (state == MEM_REQ) || (state == WR_REQ);
        mem_req_write = (state == WR_REQ);
        mem_req_addr = (state == WR_REQ) ? {saved_addr[ADDR_BITS-1:2], 2'b00}
                                         : (line_base | (ADDR_BITS'(rf_cnt) << OFFSET_BITS));
        mem_req_wdata = saved_wdata;
        mem_req_wstrb = (state == WR_REQ) ? saved_wstrb : 4'b0000;

        mem_resp_ready = (state == MEM_WAIT) || (state == WR_WAIT);
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
            rf_cnt <= '0;

            for (i = 0; i < LINE_COUNT; i++) begin
                tag_array[i] <= '0;
                valid_array[i] <= 1'b0;
            end

            for (i = 0; i < LINE_COUNT*LINE_WORDS; i++) begin
                data_array[i] <= '0;
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
                    if (saved_write) begin
                        state <= WR_REQ;
                    end else if (hit) begin
                        saved_rdata <= cur_word;
                        state <= RESP;
                    end else begin
                        valid_array[index] <= 1'b0;
                        tag_array[index] <= tag;
                        rf_cnt <= '0;
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
                        if (mem_resp_error) begin
                            saved_error <= 1'b1;
                            saved_rdata <= '0;
                            state <= RESP;
                        end else begin
                            data_array[{index, rf_cnt}] <= mem_resp_rdata;

                            if (rf_cnt == widx) begin
                                saved_rdata <= mem_resp_rdata;
                            end

                            if (&rf_cnt) begin
                                valid_array[index] <= 1'b1;
                                state <= RESP;
                            end else begin
                                rf_cnt <= rf_cnt + 1'b1;
                                state <= MEM_REQ;
                            end
                        end
                    end
                end

                WR_REQ: begin
                    if (mem_req_valid && mem_req_ready) begin
                        state <= WR_WAIT;
                    end
                end

                WR_WAIT: begin
                    if (mem_resp_valid && mem_resp_ready) begin
                        saved_error <= mem_resp_error;
                        saved_rdata <= mem_resp_rdata;

                        if (!mem_resp_error && hit) begin
                            data_array[{index, widx}] <= merged_wdata;
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