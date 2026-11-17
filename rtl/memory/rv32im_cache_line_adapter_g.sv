
module rv32im_cache_line_adapter_g #(
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int LINE_BYTES = 32,
    parameter int WORD_BITS = 32,
    parameter int WORDS_PER_LINE = LINE_BYTES / (WORD_BITS / 8),
    parameter int WORD_INDEX_BITS = $clog2(WORDS_PER_LINE),
    parameter int LINE_BITS = LINE_BYTES * 8
) (
    input logic [ADDR_BITS-1:0] addr,

    input logic [LINE_BITS-1:0] line_data,

    output logic [WORD_BITS-1:0] word_data,
    output logic [WORD_INDEX_BITS-1:0] word_index,
    output logic [ADDR_BITS-1:0] line_addr,

    input logic [WORD_BITS-1:0] write_word_data,
    input logic [3:0] write_word_strb,
    input logic write_word_valid,

    output logic [LINE_BITS-1:0] updated_line_data
);

    localparam int BYTE_OFFSET_BITS = $clog2(LINE_BYTES);
    localparam int WORD_OFFSET_BITS = $clog2(WORD_BITS / 8);

    always_comb begin
        line_addr = {
            addr[ADDR_BITS-1:BYTE_OFFSET_BITS],
            {BYTE_OFFSET_BITS{1'b0}}
        };

        word_index = addr[BYTE_OFFSET_BITS-1:WORD_OFFSET_BITS];

        word_data =
            line_data[word_index * WORD_BITS +: WORD_BITS];

        updated_line_data = line_data;

        if (write_word_valid) begin
            for (int b = 0; b < WORD_BITS / 8; b++) begin
                if (write_word_strb[b]) begin
                    updated_line_data[
                        word_index * WORD_BITS + b * 8 +: 8
                    ] = write_word_data[b * 8 +: 8];
                end
            end
        end
    end

endmodule
