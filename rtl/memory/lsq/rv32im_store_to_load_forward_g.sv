
module rv32im_store_to_load_forward_g #(
    parameter int DEPTH = 16,
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int TAG_BITS = 6
) (
    input logic load_valid,
    input logic [ADDR_BITS-1:0] load_addr,
    input logic [1:0] load_size,

    input logic [DEPTH-1:0] store_valid,
    input logic [DEPTH-1:0] store_addr_valid,
    input logic [DEPTH-1:0] store_data_valid,
    input logic [DEPTH-1:0][ADDR_BITS-1:0] store_addr,
    input logic [DEPTH-1:0][DATA_BITS-1:0] store_data,
    input logic [DEPTH-1:0][3:0] store_wstrb,
    input logic [DEPTH-1:0][TAG_BITS-1:0] store_rob_tag,

    input logic [TAG_BITS-1:0] load_rob_tag,

    output logic forward_valid,
    output logic forward_wait,
    output logic [DATA_BITS-1:0] forward_data,
    output logic [3:0] forward_byte_mask
);

    logic [3:0] load_byte_mask;
    logic [3:0] covered_byte_mask;
    logic [3:0] store_byte_mask;
    logic [3:0] overlap_byte_mask;

    logic [DATA_BITS-1:0] assembled_data;
    logic [ADDR_BITS-1:0] aligned_load_addr;

    logic [DEPTH-1:0] older_store_mask;
    logic [DEPTH-1:0] matching_store_mask;

    logic unknown_older_store;
    logic complete_coverage;

    always_comb begin
        load_byte_mask = 4'b0000;
        covered_byte_mask = 4'b0000;
        store_byte_mask = 4'b0000;
        overlap_byte_mask = 4'b0000;
        assembled_data = '0;

        older_store_mask = '0;
        matching_store_mask = '0;

        unknown_older_store = 1'b0;
        complete_coverage = 1'b0;

        forward_valid = 1'b0;
        forward_wait = 1'b0;
        forward_data = '0;
        forward_byte_mask = '0;

        aligned_load_addr = {load_addr[ADDR_BITS-1:2], 2'b00};

        case (load_size)
            2'b00: load_byte_mask = 4'b0001 << load_addr[1:0];
            2'b01: load_byte_mask = 4'b0011 << load_addr[1:0];
            2'b10: load_byte_mask = 4'b1111;
            default: load_byte_mask = 4'b0000;
        endcase

        for (int i = 0; i < DEPTH; i++) begin
            older_store_mask[i] =
                store_valid[i] &&
                (store_rob_tag[i] < load_rob_tag);

            if (older_store_mask[i] && !store_addr_valid[i]) begin
                unknown_older_store = 1'b1;
            end

            if (older_store_mask[i] &&
                store_addr_valid[i] &&
                {store_addr[i][ADDR_BITS-1:2], 2'b00} ==
                aligned_load_addr) begin

                matching_store_mask[i] = 1'b1;

                if (!store_data_valid[i]) begin
                    forward_wait = 1'b1;
                end else begin
                    store_byte_mask = store_wstrb[i];

                    overlap_byte_mask =
                        store_byte_mask & load_byte_mask;

                    for (int b = 0; b < 4; b++) begin
                        if (overlap_byte_mask[b]) begin
                            assembled_data[b*8 +: 8] =
                                store_data[i][b*8 +: 8];

                            covered_byte_mask[b] = 1'b1;
                        end
                    end
                end
            end
        end

        complete_coverage =
            ((covered_byte_mask & load_byte_mask) == load_byte_mask);

        if (load_valid && unknown_older_store) begin
            forward_wait = 1'b1;
        end else if (load_valid && complete_coverage && !forward_wait) begin
            forward_valid = 1'b1;
            forward_data = assembled_data;
            forward_byte_mask = covered_byte_mask;
        end
    end

endmodule
