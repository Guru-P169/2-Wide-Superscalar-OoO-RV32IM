
module rv32im_axi4_id_tracker_g #(
    parameter int ID_BITS = 4,
    parameter int DEPTH = (1 << ID_BITS)
) (
    input logic clk,
    input logic rst_n,

    input logic alloc_req,
    output logic alloc_grant,
    output logic [ID_BITS-1:0] alloc_id,

    input logic free_valid,
    input logic [ID_BITS-1:0] free_id,

    output logic full,
    output logic [DEPTH-1:0] active_ids
);

    logic [DEPTH-1:0] active_ids_next;
    logic free_found;
    integer free_index;

    always_comb begin
        alloc_grant = 1'b0;
        alloc_id = '0;
        free_found = 1'b0;
        free_index = 0;

        for (int i = 0; i < DEPTH; i = i + 1) begin
            if (!active_ids[i] && !free_found) begin
                free_found = 1'b1;
                free_index = i;
            end
        end

        if (alloc_req && free_found) begin
            alloc_grant = 1'b1;
            alloc_id = ID_BITS'(free_index);
        end

        full = !free_found;
    end

    always_comb begin
        active_ids_next = active_ids;

        if (free_valid && free_id < DEPTH)
            active_ids_next[free_id] = 1'b0;

        if (alloc_grant)
            active_ids_next[alloc_id] = 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_ids <= '0;
        else
            active_ids <= active_ids_next;
    end

endmodule
