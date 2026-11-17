
module rv32im_rename_g #(
    parameter int ARCH_REGS = 32,
    parameter int PHYS_REGS = 64,
    parameter int ARCH_BITS = $clog2(ARCH_REGS),
    parameter int PHYS_BITS = $clog2(PHYS_REGS)
) (
    input logic clk,
    input logic rst_n,

    input logic flush,

    input logic in_valid0,
    input logic [ARCH_BITS-1:0] in_rs1_0,
    input logic [ARCH_BITS-1:0] in_rs2_0,
    input logic [ARCH_BITS-1:0] in_rd0,
    input logic in_uses_rs1_0,
    input logic in_uses_rs2_0,
    input logic in_writes_rd0,

    input logic in_valid1,
    input logic [ARCH_BITS-1:0] in_rs1_1,
    input logic [ARCH_BITS-1:0] in_rs2_1,
    input logic [ARCH_BITS-1:0] in_rd1,
    input logic in_uses_rs1_1,
    input logic in_uses_rs2_1,
    input logic in_writes_rd1,

    output logic in_ready0,
    output logic in_ready1,

    output logic out_valid0,
    output logic [PHYS_BITS-1:0] out_rs1_0,
    output logic [PHYS_BITS-1:0] out_rs2_0,
    output logic [PHYS_BITS-1:0] out_rd0,
    output logic [PHYS_BITS-1:0] out_old_rd0,

    output logic out_valid1,
    output logic [PHYS_BITS-1:0] out_rs1_1,
    output logic [PHYS_BITS-1:0] out_rs2_1,
    output logic [PHYS_BITS-1:0] out_rd1,
    output logic [PHYS_BITS-1:0] out_old_rd1,

    input logic free_valid0,
    input logic [PHYS_BITS-1:0] free_preg0,
    input logic free_valid1,
    input logic [PHYS_BITS-1:0] free_preg1,

    input logic checkpoint_restore,
    input logic [ARCH_REGS*PHYS_BITS-1:0] restore_map,
    input logic [PHYS_REGS-1:0] restore_bitmap,

    output logic [ARCH_REGS*PHYS_BITS-1:0] checkpoint_map,
    output logic [PHYS_REGS-1:0] free_bitmap
);

    logic alloc_req0;
    logic alloc_req1;
    logic alloc_grant0;
    logic alloc_grant1;
    logic [PHYS_BITS-1:0] alloc_preg0;
    logic [PHYS_BITS-1:0] alloc_preg1;

    logic rename_valid0;
    logic rename_valid1;

    logic [PHYS_BITS-1:0] rat_src0;
    logic [PHYS_BITS-1:0] rat_src1;
    logic [PHYS_BITS-1:0] rat_src2;
    logic [PHYS_BITS-1:0] rat_src3;

    logic [PHYS_BITS-1:0] old_phys0;
    logic [PHYS_BITS-1:0] old_phys1;

    logic [PHYS_BITS-1:0] rat_rename_phys0;
    logic [PHYS_BITS-1:0] rat_rename_phys1;

    logic [PHYS_REGS-1:0] checkpoint_bitmap;

    logic want_dst0;
    logic want_dst1;
    logic accept0;
    logic accept1;

    assign want_dst0 =
        in_valid0 &&
        in_writes_rd0 &&
        (in_rd0 != '0);

    assign want_dst1 =
        in_valid1 &&
        in_writes_rd1 &&
        (in_rd1 != '0);

    assign alloc_req0 = want_dst0 && !flush;

    assign alloc_req1 =
        want_dst1 &&
        !flush &&
        in_valid0 &&
        (!want_dst0 || alloc_grant0);

    always_comb begin
        accept0 = in_valid0 && !flush;
        accept1 = in_valid1 && !flush && accept0;

        if (want_dst0 && !alloc_grant0)
            accept0 = 1'b0;

        if (accept0 && want_dst1 && !alloc_grant1)
            accept1 = 1'b0;

        in_ready0 = !flush &&
                    (!in_valid0 || !want_dst0 || alloc_grant0);

        in_ready1 = !flush &&
                    (!in_valid1 ||
                     (accept0 && (!want_dst1 || alloc_grant1)));

        out_valid0 = accept0;
        out_valid1 = accept1;
    end

    assign rat_rename_phys0 = alloc_preg0;
    assign rat_rename_phys1 = alloc_preg1;

    rv32im_free_list_g #(
        .ARCH_REGS(ARCH_REGS),
        .PHYS_REGS(PHYS_REGS),
        .PHYS_BITS(PHYS_BITS)
    ) free_list (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_req0(alloc_req0),
        .alloc_grant0(alloc_grant0),
        .alloc_preg0(alloc_preg0),
        .alloc_req1(alloc_req1),
        .alloc_grant1(alloc_grant1),
        .alloc_preg1(alloc_preg1),
        .free_valid0(free_valid0),
        .free_preg0(free_preg0),
        .free_valid1(free_valid1),
        .free_preg1(free_preg1),
        .checkpoint_restore(checkpoint_restore),
        .restore_bitmap(restore_bitmap),
        .checkpoint_bitmap(checkpoint_bitmap),
        .free_bitmap(free_bitmap)
    );

    rv32im_rat_g #(
        .ARCH_REGS(ARCH_REGS),
        .PHYS_REGS(PHYS_REGS),
        .ARCH_BITS(ARCH_BITS),
        .PHYS_BITS(PHYS_BITS)
    ) rat (
        .clk(clk),
        .rst_n(rst_n),

        .src_valid0(out_valid0 && in_uses_rs1_0),
        .src_arch0(in_rs1_0),
        .src_phys0(rat_src0),

        .src_valid1(out_valid0 && in_uses_rs2_0),
        .src_arch1(in_rs2_0),
        .src_phys1(rat_src1),

        .src_valid2(out_valid1 && in_uses_rs1_1),
        .src_arch2(in_rs1_1),
        .src_phys2(rat_src2),

        .src_valid3(out_valid1 && in_uses_rs2_1),
        .src_arch3(in_rs2_1),
        .src_phys3(rat_src3),

        .rename_valid0(accept0 && want_dst0),
        .rename_arch0(in_rd0),
        .rename_phys0(rat_rename_phys0),
        .old_phys0(old_phys0),

        .rename_valid1(accept1 && want_dst1),
        .rename_arch1(in_rd1),
        .rename_phys1(rat_rename_phys1),
        .old_phys1(old_phys1),

        .checkpoint_save(1'b0),
        .checkpoint_map(checkpoint_map),
        .checkpoint_restore(checkpoint_restore),
        .restore_map(restore_map)
    );

    always_comb begin
        out_rs1_0 = rat_src0;
        out_rs2_0 = rat_src1;
        out_rd0 = want_dst0 ? alloc_preg0 : '0;
        out_old_rd0 = want_dst0 ? old_phys0 : '0;

        out_rs1_1 = rat_src2;
        out_rs2_1 = rat_src3;
        out_rd1 = want_dst1 ? alloc_preg1 : '0;
        out_old_rd1 = want_dst1 ? old_phys1 : '0;
    end

endmodule
