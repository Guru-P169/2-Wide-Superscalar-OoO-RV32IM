
module rv32im_rat_g #(
    parameter int ARCH_REGS = 32,
    parameter int PHYS_REGS = 64,
    parameter int ARCH_BITS = $clog2(ARCH_REGS),
    parameter int PHYS_BITS = $clog2(PHYS_REGS)
) (
    input logic clk,
    input logic rst_n,

    input logic src_valid0,
    input logic [ARCH_BITS-1:0] src_arch0,
    output logic [PHYS_BITS-1:0] src_phys0,

    input logic src_valid1,
    input logic [ARCH_BITS-1:0] src_arch1,
    output logic [PHYS_BITS-1:0] src_phys1,

    input logic src_valid2,
    input logic [ARCH_BITS-1:0] src_arch2,
    output logic [PHYS_BITS-1:0] src_phys2,

    input logic src_valid3,
    input logic [ARCH_BITS-1:0] src_arch3,
    output logic [PHYS_BITS-1:0] src_phys3,

    input logic rename_valid0,
    input logic [ARCH_BITS-1:0] rename_arch0,
    input logic [PHYS_BITS-1:0] rename_phys0,
    output logic [PHYS_BITS-1:0] old_phys0,

    input logic rename_valid1,
    input logic [ARCH_BITS-1:0] rename_arch1,
    input logic [PHYS_BITS-1:0] rename_phys1,
    output logic [PHYS_BITS-1:0] old_phys1,

    input logic checkpoint_save,
    output logic [ARCH_REGS*PHYS_BITS-1:0] checkpoint_map,

    input logic checkpoint_restore,
    input logic [ARCH_REGS*PHYS_BITS-1:0] restore_map
);

    logic [PHYS_BITS-1:0] rename_map [0:ARCH_REGS-1];
    logic [PHYS_BITS-1:0] map_next [0:ARCH_REGS-1];

    logic lane0_write;
    logic lane1_write;

    always_comb begin
        for (integer j = 0; j < ARCH_REGS; j = j + 1)
            map_next[j] = rename_map[j];

        lane0_write =
            rename_valid0 &&
            (rename_arch0 != '0) &&
            (rename_arch0 < ARCH_REGS) &&
            (rename_phys0 < PHYS_REGS) &&
            (rename_phys0 != '0);

        lane1_write =
            rename_valid1 &&
            (rename_arch1 != '0) &&
            (rename_arch1 < ARCH_REGS) &&
            (rename_phys1 < PHYS_REGS) &&
            (rename_phys1 != '0);

        old_phys0 = '0;
        old_phys1 = '0;

        if (lane0_write)
            old_phys0 = rename_map[rename_arch0];

        if (lane1_write) begin
            if (lane0_write && (rename_arch0 == rename_arch1))
                old_phys1 = rename_phys0;
            else
                old_phys1 = rename_map[rename_arch1];
        end

        if (lane0_write)
            map_next[rename_arch0] = rename_phys0;

        if (lane1_write)
            map_next[rename_arch1] = rename_phys1;

        src_phys0 = '0;
        src_phys1 = '0;
        src_phys2 = '0;
        src_phys3 = '0;

        if (src_valid0 &&
            (src_arch0 != '0) &&
            (src_arch0 < ARCH_REGS))
            src_phys0 = rename_map[src_arch0];

        if (src_valid1 &&
            (src_arch1 != '0) &&
            (src_arch1 < ARCH_REGS))
            src_phys1 = rename_map[src_arch1];

        if (src_valid2 &&
            (src_arch2 != '0) &&
            (src_arch2 < ARCH_REGS))
            src_phys2 = rename_map[src_arch2];

        if (src_valid3 &&
            (src_arch3 != '0) &&
            (src_arch3 < ARCH_REGS))
            src_phys3 = rename_map[src_arch3];

        if (src_valid2 && lane0_write && (src_arch2 == rename_arch0))
            src_phys2 = rename_phys0;

        if (src_valid3 && lane0_write && (src_arch3 == rename_arch0))
            src_phys3 = rename_phys0;

        for (integer j = 0; j < ARCH_REGS; j = j + 1)
            checkpoint_map[j*PHYS_BITS +: PHYS_BITS] = rename_map[j];

        checkpoint_map[0 +: PHYS_BITS] = '0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < ARCH_REGS; i = i + 1)
                rename_map[i] <= PHYS_BITS'(i);
        end else if (checkpoint_restore) begin
            for (integer i = 0; i < ARCH_REGS; i = i + 1)
                rename_map[i] <= restore_map[i*PHYS_BITS +: PHYS_BITS];

            rename_map[0] <= '0;
        end else begin
            for (integer i = 1; i < ARCH_REGS; i = i + 1)
                rename_map[i] <= map_next[i];

            rename_map[0] <= '0;
        end
    end

endmodule
