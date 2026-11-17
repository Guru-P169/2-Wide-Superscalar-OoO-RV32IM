
module rv32im_commit_stage_g #(
    parameter int ROB_BITS = 5,
    parameter int PC_BITS = 32,
    parameter int ARCH_BITS = 5,
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic rob_commit_valid0,
    output logic rob_commit_ready0,
    input logic [ROB_BITS-1:0] rob_commit_rob_idx0,
    input logic [PC_BITS-1:0] rob_commit_pc0,
    input logic [ARCH_BITS-1:0] rob_commit_rd0,
    input logic [PHYS_BITS-1:0] rob_commit_pdst0,
    input logic [PHYS_BITS-1:0] rob_commit_old_pdst0,
    input logic [DATA_BITS-1:0] rob_commit_data0,
    input logic rob_commit_writes_rd0,

    input logic rob_commit_valid1,
    output logic rob_commit_ready1,
    input logic [ROB_BITS-1:0] rob_commit_rob_idx1,
    input logic [PC_BITS-1:0] rob_commit_pc1,
    input logic [ARCH_BITS-1:0] rob_commit_rd1,
    input logic [PHYS_BITS-1:0] rob_commit_pdst1,
    input logic [PHYS_BITS-1:0] rob_commit_old_pdst1,
    input logic [DATA_BITS-1:0] rob_commit_data1,
    input logic rob_commit_writes_rd1,

    output logic arch_write_valid0,
    output logic [ARCH_BITS-1:0] arch_write_rd0,
    output logic [DATA_BITS-1:0] arch_write_data0,

    output logic arch_write_valid1,
    output logic [ARCH_BITS-1:0] arch_write_rd1,
    output logic [DATA_BITS-1:0] arch_write_data1,

    output logic free_valid0,
    output logic [PHYS_BITS-1:0] free_preg0,
    output logic free_valid1,
    output logic [PHYS_BITS-1:0] free_preg1,

    output logic retire_valid0,
    output logic [ROB_BITS-1:0] retire_rob_idx0,
    output logic [PC_BITS-1:0] retire_pc0,

    output logic retire_valid1,
    output logic [ROB_BITS-1:0] retire_rob_idx1,
    output logic [PC_BITS-1:0] retire_pc1
);

    logic retire0;
    logic retire1;

    always_comb begin
        rob_commit_ready0 = !flush;
        rob_commit_ready1 = !flush && rob_commit_valid0;

        retire0 = rob_commit_valid0 && rob_commit_ready0;
        retire1 = rob_commit_valid1 &&
                  rob_commit_ready1 &&
                  retire0;

        arch_write_valid0 = retire0 &&
                            rob_commit_writes_rd0 &&
                            (rob_commit_rd0 != '0);

        arch_write_rd0 = rob_commit_rd0;
        arch_write_data0 = rob_commit_data0;

        arch_write_valid1 = retire1 &&
                            rob_commit_writes_rd1 &&
                            (rob_commit_rd1 != '0);

        arch_write_rd1 = rob_commit_rd1;
        arch_write_data1 = rob_commit_data1;

        free_valid0 = retire0 &&
                      rob_commit_writes_rd0 &&
                      (rob_commit_old_pdst0 != '0);

        free_preg0 = rob_commit_old_pdst0;

        free_valid1 = retire1 &&
                      rob_commit_writes_rd1 &&
                      (rob_commit_old_pdst1 != '0);

        free_preg1 = rob_commit_old_pdst1;

        retire_valid0 = retire0;
        retire_rob_idx0 = rob_commit_rob_idx0;
        retire_pc0 = rob_commit_pc0;

        retire_valid1 = retire1;
        retire_rob_idx1 = rob_commit_rob_idx1;
        retire_pc1 = rob_commit_pc1;
    end

endmodule
