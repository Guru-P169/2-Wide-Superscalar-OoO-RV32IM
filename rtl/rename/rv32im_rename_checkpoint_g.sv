
module rv32im_rename_checkpoint_g #(
    parameter int ARCH_REGS = 32,
    parameter int PHYS_REGS = 64,
    parameter int MAX_CHECKPOINTS = 8,
    parameter int ARCH_BITS = $clog2(ARCH_REGS),
    parameter int PHYS_BITS = $clog2(PHYS_REGS),
    parameter int CHECKPOINT_BITS =
        (MAX_CHECKPOINTS <= 1) ? 1 : $clog2(MAX_CHECKPOINTS)
) (
    input logic clk,
    input logic rst_n,

    input logic save_valid,
    output logic save_ready,
    input logic [ARCH_REGS*PHYS_BITS-1:0] save_map,
    input logic [PHYS_REGS-1:0] save_free_bitmap,
    output logic [CHECKPOINT_BITS-1:0] save_checkpoint_id,

    input logic restore_valid,
    input logic [CHECKPOINT_BITS-1:0] restore_checkpoint_id,
    output logic restore_ready,
    output logic [ARCH_REGS*PHYS_BITS-1:0] restore_map,
    output logic [PHYS_REGS-1:0] restore_free_bitmap,

    input logic release_valid,
    input logic [CHECKPOINT_BITS-1:0] release_checkpoint_id,

    output logic [MAX_CHECKPOINTS-1:0] checkpoint_valid
);

    logic [ARCH_REGS*PHYS_BITS-1:0] map_store [0:MAX_CHECKPOINTS-1];
    logic [PHYS_REGS-1:0] free_store [0:MAX_CHECKPOINTS-1];

    logic [MAX_CHECKPOINTS-1:0] valid_next;
    logic found_free;
    logic release_id_valid;
    logic restore_id_valid;
    logic restore_blocking_save;

    logic [CHECKPOINT_BITS-1:0] free_id;

    always_comb begin
        valid_next = checkpoint_valid;

        release_id_valid =
            (release_checkpoint_id < MAX_CHECKPOINTS);

        restore_id_valid =
            (restore_checkpoint_id < MAX_CHECKPOINTS);

        if (release_valid &&
            release_id_valid &&
            checkpoint_valid[release_checkpoint_id])
            valid_next[release_checkpoint_id] = 1'b0;

        restore_ready = 1'b0;
        restore_map = '0;
        restore_free_bitmap = '0;

        if (restore_valid &&
            restore_id_valid &&
            checkpoint_valid[restore_checkpoint_id] &&
            !(release_valid &&
              release_id_valid &&
              (release_checkpoint_id == restore_checkpoint_id))) begin

            restore_ready = 1'b1;
            restore_map = map_store[restore_checkpoint_id];
            restore_free_bitmap = free_store[restore_checkpoint_id];
        end

        found_free = 1'b0;
        free_id = '0;

        for (integer j = 0; j < MAX_CHECKPOINTS; j = j + 1) begin
            if (!valid_next[j] && !found_free) begin
                found_free = 1'b1;
                free_id = CHECKPOINT_BITS'(j);
            end
        end

        restore_blocking_save = restore_ready;

        save_ready = found_free && !restore_blocking_save;
        save_checkpoint_id = free_id;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            checkpoint_valid <= '0;

            for (integer i = 0; i < MAX_CHECKPOINTS; i = i + 1) begin
                map_store[i] <= '0;
                free_store[i] <= '0;
            end
        end else begin
            if (release_valid &&
                release_id_valid &&
                checkpoint_valid[release_checkpoint_id])
                checkpoint_valid[release_checkpoint_id] <= 1'b0;

            if (save_valid && save_ready) begin
                map_store[save_checkpoint_id] <= save_map;
                free_store[save_checkpoint_id] <= save_free_bitmap;
                checkpoint_valid[save_checkpoint_id] <= 1'b1;
            end
        end
    end

endmodule
