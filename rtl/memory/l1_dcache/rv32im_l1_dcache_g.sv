module rv32im_l1_dcache_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int INDEX_BITS = 4
) (
    input logic clk,
    input logic rst_n,

    input logic req_valid,
    output logic req_ready,
    input logic req_write,
    input logic [ADDR_BITS-1:0] req_addr,
    input logic [DATA_BITS-1:0] req_wdata,
    input logic [1:0] req_size,

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

    localparam int LINE_COUNT = 1 << INDEX_BITS;
    localparam int OFFSET_BITS = 2;
    localparam int TAG_BITS = ADDR_BITS - INDEX_BITS - OFFSET_BITS;

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
    logic [1:0] saved_size;
    logic [DATA_BITS-1:0] saved_rdata;
    logic saved_error;

    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    logic hit;
    logic [1:0] byte_offset;
    logic [3:0] access_mask;
    logic [DATA_BITS-1:0] shifted_wdata;
    logic [DATA_BITS-1:0] shifted_rdata;
    logic [DATA_BITS-1:0] merged_wdata;
    logic [DATA_BITS-1:0] fill_rdata;

    // lookup performed at request-accept time (removes the separate LOOKUP cycle)
    logic [INDEX_BITS-1:0] r_index;
    logic [TAG_BITS-1:0] r_tag;
    logic [1:0] r_off;
    logic r_hit;
    logic [3:0] r_mask;
    logic [DATA_BITS-1:0] r_swdata;
    logic [DATA_BITS-1:0] r_srdata;
    logic [DATA_BITS-1:0] r_merged;

    integer i;

    always_comb begin
        r_index = req_addr[OFFSET_BITS +: INDEX_BITS];
        r_tag = req_addr[ADDR_BITS-1 -: TAG_BITS];
        r_off = req_addr[1:0];
        r_hit = valid_array[r_index] && (tag_array[r_index] == r_tag);

        r_mask = 4'b0000;
        case (req_size)
            2'b00: r_mask = 4'b0001 << r_off;
            2'b01: r_mask = 4'b0011 << r_off;
            2'b10: r_mask = 4'b1111;
            default: r_mask = 4'b0000;
        endcase

        r_swdata = req_wdata << (r_off * 8);
        r_srdata = data_array[r_index] >> (r_off * 8);
        r_merged = data_array[r_index];
        for (int b = 0; b < 4; b++) begin
            if (r_mask[b])
                r_merged[b*8 +: 8] = r_swdata[b*8 +: 8];
        end
    end

    always_comb begin
        index = saved_addr[OFFSET_BITS +: INDEX_BITS];
        tag = saved_addr[ADDR_BITS-1 -: TAG_BITS];
        byte_offset = saved_addr[1:0];

        hit = valid_array[index] && (tag_array[index] == tag);

        access_mask = 4'b0000;
        case (saved_size)
            2'b00: access_mask = 4'b0001 << byte_offset;
            2'b01: access_mask = 4'b0011 << byte_offset;
            2'b10: access_mask = 4'b1111;
            default: access_mask = 4'b0000;
        endcase

        shifted_wdata = saved_wdata << (byte_offset * 8);
        shifted_rdata = data_array[index] >> (byte_offset * 8);
        fill_rdata = mem_resp_rdata >> (byte_offset * 8);

        merged_wdata = data_array[index];

        for (int b = 0; b < 4; b++) begin
            if (access_mask[b]) begin
                merged_wdata[b*8 +: 8] =
                    shifted_wdata[b*8 +: 8];
            end
        end

        req_ready = (state == IDLE);
        resp_valid = (state == RESP);
        resp_rdata = saved_rdata;
        resp_error = saved_error;

        mem_req_valid = (state == MEM_REQ);
        mem_req_write = saved_write;
        mem_req_addr = {saved_addr[ADDR_BITS-1:2], 2'b00};
        mem_req_wdata = shifted_wdata;
        mem_req_wstrb = saved_write ? access_mask : 4'b0000;

        mem_resp_ready = (state == MEM_WAIT);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_addr <= '0;
            saved_write <= 1'b0;
            saved_wdata <= '0;
            saved_size <= '0;
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
                        saved_size <= req_size;
                        saved_error <= 1'b0;
                        if (r_hit && !req_write) begin
                            case (req_size)
                                2'b00: saved_rdata <= {{24{r_srdata[7]}}, r_srdata[7:0]};
                                2'b01: saved_rdata <= {{16{r_srdata[15]}}, r_srdata[15:0]};
                                2'b10: saved_rdata <= r_srdata;
                                default: saved_rdata <= '0;
                            endcase
                            state <= RESP;
                        end else if (r_hit && req_write) begin
                            data_array[r_index] <= r_merged;
                            state <= MEM_REQ;
                        end else begin
                            state <= MEM_REQ;
                        end
                    end
                end

                LOOKUP: begin
                    if (hit && !saved_write) begin
                        case (saved_size)
                            2'b00: saved_rdata <=
                                {{24{shifted_rdata[7]}},
                                 shifted_rdata[7:0]};
                            2'b01: saved_rdata <=
                                {{16{shifted_rdata[15]}},
                                 shifted_rdata[15:0]};
                            2'b10: saved_rdata <= shifted_rdata;
                            default: saved_rdata <= '0;
                        endcase
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

                        if (!saved_error && !mem_resp_error) begin
                            if (saved_write) begin
                                saved_rdata <= '0;
                            end else begin
                                data_array[index] <= mem_resp_rdata;
                                tag_array[index] <= tag;
                                valid_array[index] <= 1'b1;

                                case (saved_size)
                                    2'b00: saved_rdata <=
                                        {{24{fill_rdata[7]}}, fill_rdata[7:0]};
                                    2'b01: saved_rdata <=
                                        {{16{fill_rdata[15]}}, fill_rdata[15:0]};
                                    2'b10: saved_rdata <= fill_rdata;
                                    default: saved_rdata <= '0;
                                endcase
                            end
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