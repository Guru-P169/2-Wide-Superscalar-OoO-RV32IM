
module rv32im_lsu_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  req_valid,
    output logic                  req_ready,

    input  logic                  req_is_load,
    input  logic                  req_is_store,
    input  logic [1:0]            req_size,
    input  logic                  req_unsigned,
    input  logic [ADDR_BITS-1:0]  req_base,
    input  logic [DATA_BITS-1:0]  req_immediate,
    input  logic [DATA_BITS-1:0]  req_store_data,

    output logic                  mem_req_valid,
    input  logic                  mem_req_ready,
    output logic                  mem_req_write,
    output logic [ADDR_BITS-1:0]  mem_req_addr,
    output logic [DATA_BITS-1:0]  mem_req_wdata,
    output logic [DATA_BITS/8-1:0] mem_req_strb,

    input  logic                  mem_rsp_valid,
    input  logic [DATA_BITS-1:0]  mem_rsp_rdata,

    output logic                  result_valid,
    output logic [DATA_BITS-1:0]  result_data,
    output logic                  busy,
    output logic                  misaligned
);

    localparam logic [1:0] SIZE_BYTE = 2'b00;
    localparam logic [1:0] SIZE_HALF = 2'b01;
    localparam logic [1:0] SIZE_WORD = 2'b10;

    logic [ADDR_BITS-1:0] effective_addr;
    logic [1:0]           byte_offset;

    logic                 pending_load;
    logic [1:0]           saved_size;
    logic                 saved_unsigned;
    logic [1:0]           saved_offset;

    logic [7:0]  selected_byte;
    logic [15:0] selected_half;
    logic [DATA_BITS-1:0] shifted_rdata;

    always_comb begin
        effective_addr = req_base + req_immediate;
        byte_offset = effective_addr[1:0];

        mem_req_addr = effective_addr & {{(ADDR_BITS-2){1'b1}}, 2'b00};
        mem_req_write = req_is_store;
        mem_req_wdata = '0;
        mem_req_strb = '0;

        misaligned = 1'b0;

        case (req_size)
            SIZE_BYTE: begin
                mem_req_strb = {{(DATA_BITS/8-1){1'b0}}, 1'b1} << byte_offset;
                mem_req_wdata = req_store_data << (byte_offset * 8);
            end

            SIZE_HALF: begin
                if (byte_offset[0])
                    misaligned = 1'b1;

                mem_req_strb = {{(DATA_BITS/8-2){1'b0}}, 2'b11} << byte_offset;
                mem_req_wdata = req_store_data << (byte_offset * 8);
            end

            SIZE_WORD: begin
                if (byte_offset != 2'b00)
                    misaligned = 1'b1;

                mem_req_strb = '1;
                mem_req_wdata = req_store_data;
            end

            default: begin
                misaligned = 1'b1;
            end
        endcase

        mem_req_valid = req_valid &&
                        (req_is_load || req_is_store) &&
                        !misaligned &&
                        !busy;

        req_ready = mem_req_ready &&
                    mem_req_valid;

        // shifted_rdata must be computed BEFORE it is used (use-before-assign inside an
        // always_comb gives stale data in event-driven simulators and a latch in synthesis)
        shifted_rdata = mem_rsp_rdata >> (saved_offset * 8);
        selected_byte = shifted_rdata[7:0];
        selected_half = shifted_rdata[15:0];

        result_data = '0;

        case (saved_size)
            SIZE_BYTE: begin
                if (saved_unsigned)
                    result_data = {{(DATA_BITS-8){1'b0}}, selected_byte};
                else
                    result_data = {{(DATA_BITS-8){selected_byte[7]}}, selected_byte};
            end

            SIZE_HALF: begin
                if (saved_unsigned)
                    result_data = {{(DATA_BITS-16){1'b0}}, selected_half};
                else
                    result_data = {{(DATA_BITS-16){selected_half[15]}}, selected_half};
            end

            SIZE_WORD: begin
                result_data = mem_rsp_rdata;
            end

            default: begin
                result_data = '0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_load <= 1'b0;
            saved_size <= SIZE_WORD;
            saved_unsigned <= 1'b0;
            saved_offset <= 2'b00;
            result_valid <= 1'b0;
            busy <= 1'b0;
        end
        else begin
            result_valid <= 1'b0;

            if (req_ready) begin
                busy <= 1'b1;

                if (req_is_load) begin
                    pending_load <= 1'b1;
                    saved_size <= req_size;
                    saved_unsigned <= req_unsigned;
                    saved_offset <= byte_offset;
                end
                else begin
                    pending_load <= 1'b0;
                end
            end

            if (busy && mem_rsp_valid) begin
                busy <= 1'b0;

                if (pending_load) begin
                    result_valid <= 1'b1;
                end

                pending_load <= 1'b0;
            end
        end
    end

endmodule
