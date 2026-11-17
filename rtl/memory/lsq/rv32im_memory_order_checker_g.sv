
module rv32im_memory_order_checker_g #(
    parameter int DEPTH = 16,
    parameter int ADDR_BITS = 32,
    parameter int TAG_BITS = 6
) (
    input logic load_valid,
    input logic [ADDR_BITS-1:0] load_addr,
    input logic load_addr_valid,
    input logic [TAG_BITS-1:0] load_rob_tag,

    input logic [DEPTH-1:0] store_valid,
    input logic [DEPTH-1:0] store_addr_valid,
    input logic [DEPTH-1:0] store_data_valid,
    input logic [DEPTH-1:0][ADDR_BITS-1:0] store_addr,
    input logic [DEPTH-1:0][TAG_BITS-1:0] store_rob_tag,

    output logic load_can_execute,
    output logic load_must_wait,
    output logic store_address_unknown,
    output logic older_store_match,
    output logic [DEPTH-1:0] matching_store_mask
);

    logic [DEPTH-1:0] older_store_mask;
    logic [DEPTH-1:0] unknown_address_mask;
    logic [DEPTH-1:0] address_match_mask;

    always_comb begin
        older_store_mask = '0;
        unknown_address_mask = '0;
        address_match_mask = '0;
        matching_store_mask = '0;

        store_address_unknown = 1'b0;
        older_store_match = 1'b0;
        load_can_execute = 1'b0;
        load_must_wait = 1'b0;

        for (int i = 0; i < DEPTH; i++) begin
            older_store_mask[i] =
                store_valid[i] &&
                (store_rob_tag[i] < load_rob_tag);

            unknown_address_mask[i] =
                older_store_mask[i] &&
                !store_addr_valid[i];

            address_match_mask[i] =
                older_store_mask[i] &&
                store_addr_valid[i] &&
                (store_addr[i] == load_addr);

            matching_store_mask[i] = address_match_mask[i];
        end

        store_address_unknown = |unknown_address_mask;
        older_store_match = |address_match_mask;

        if (load_valid && load_addr_valid) begin
            if (store_address_unknown) begin
                load_must_wait = 1'b1;
            end else begin
                load_can_execute = 1'b1;
            end
        end else begin
            load_must_wait = load_valid;
        end
    end

endmodule
