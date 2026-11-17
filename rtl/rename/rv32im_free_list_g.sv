
module rv32im_free_list_g #(
    parameter int ARCH_REGS = 32,
    parameter int PHYS_REGS = 64,
    parameter int PHYS_BITS = $clog2(PHYS_REGS)
) (
    input logic clk,
    input logic rst_n,

    input logic alloc_req0,
    output logic alloc_grant0,
    output logic [PHYS_BITS-1:0] alloc_preg0,

    input logic alloc_req1,
    output logic alloc_grant1,
    output logic [PHYS_BITS-1:0] alloc_preg1,

    input logic free_valid0,
    input logic [PHYS_BITS-1:0] free_preg0,

    input logic free_valid1,
    input logic [PHYS_BITS-1:0] free_preg1,

    input logic checkpoint_restore,
    input logic [PHYS_REGS-1:0] restore_bitmap,

    output logic [PHYS_REGS-1:0] checkpoint_bitmap,
    output logic [PHYS_REGS-1:0] free_bitmap
);

    logic [PHYS_REGS-1:0] free_bitmap_work;
    logic [PHYS_REGS-1:0] free_bitmap_next;

    integer i;

    always_comb begin
        free_bitmap_work = free_bitmap;

        alloc_grant0 = 1'b0;
        alloc_grant1 = 1'b0;

        alloc_preg0 = '0;
        alloc_preg1 = '0;

        if (!checkpoint_restore) begin
            if (free_valid0 &&
                (free_preg0 != '0) &&
                (free_preg0 < PHYS_REGS))
                free_bitmap_work[free_preg0] = 1'b1;

            if (free_valid1 &&
                (free_preg1 != '0) &&
                (free_preg1 < PHYS_REGS) &&
                !(free_valid0 && (free_preg0 == free_preg1)))
                free_bitmap_work[free_preg1] = 1'b1;

            if (alloc_req0) begin
                for (i = 1; i < PHYS_REGS; i = i + 1) begin
                    if (free_bitmap_work[i] && !alloc_grant0) begin
                        alloc_preg0 = PHYS_BITS'(i);
                        alloc_grant0 = 1'b1;
                        free_bitmap_work[i] = 1'b0;
                    end
                end
            end

            if (alloc_req1) begin
                for (i = 1; i < PHYS_REGS; i = i + 1) begin
                    if (free_bitmap_work[i] && !alloc_grant1) begin
                        alloc_preg1 = PHYS_BITS'(i);
                        alloc_grant1 = 1'b1;
                        free_bitmap_work[i] = 1'b0;
                    end
                end
            end
        end

        free_bitmap_work[0] = 1'b0;
        free_bitmap_next = free_bitmap_work;

        checkpoint_bitmap = free_bitmap;
        checkpoint_bitmap[0] = 1'b0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            free_bitmap <= '0;

            for (integer j = ARCH_REGS; j < PHYS_REGS; j = j + 1)
                free_bitmap[j] <= 1'b1;
        end else if (checkpoint_restore) begin
            free_bitmap <= restore_bitmap;
            free_bitmap[0] <= 1'b0;
        end else begin
            free_bitmap <= free_bitmap_next;
            free_bitmap[0] <= 1'b0;
        end
    end

endmodule
