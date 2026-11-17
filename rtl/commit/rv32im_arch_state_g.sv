
module rv32im_arch_state_g #(
    parameter int ARCH_REGS = 32,
    parameter int DATA_BITS = 32,
    parameter int ARCH_BITS = (ARCH_REGS > 1) ? $clog2(ARCH_REGS) : 1
) (
    input logic clk,
    input logic rst_n,

    input logic commit_valid0,
    input logic [ARCH_BITS-1:0] commit_rd0,
    input logic [DATA_BITS-1:0] commit_data0,

    input logic commit_valid1,
    input logic [ARCH_BITS-1:0] commit_rd1,
    input logic [DATA_BITS-1:0] commit_data1,

    input logic [ARCH_BITS-1:0] read_addr0,
    output logic [DATA_BITS-1:0] read_data0,

    input logic [ARCH_BITS-1:0] read_addr1,
    output logic [DATA_BITS-1:0] read_data1
);

    logic [DATA_BITS-1:0] registers [0:ARCH_REGS-1];

    always_comb begin
        read_data0 = '0;
        read_data1 = '0;

        if (read_addr0 < ARCH_REGS && read_addr0 != '0)
            read_data0 = registers[read_addr0];

        if (read_addr1 < ARCH_REGS && read_addr1 != '0)
            read_data1 = registers[read_addr1];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ARCH_REGS; i = i + 1)
                registers[i] <= '0;
        end else begin
            if (commit_valid0 &&
                commit_rd0 != '0 &&
                commit_rd0 < ARCH_REGS)
                registers[commit_rd0] <= commit_data0;

            if (commit_valid1 &&
                commit_rd1 != '0 &&
                commit_rd1 < ARCH_REGS)
                registers[commit_rd1] <= commit_data1;
        end
    end

endmodule
