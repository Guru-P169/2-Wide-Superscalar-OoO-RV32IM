
module rv32im_prf_g #(
    parameter int PHYS_REGS = 64,
    parameter int DATA_BITS = 32,
    parameter int PHYS_BITS = $clog2(PHYS_REGS)
) (
    input logic clk,
    input logic rst_n,

    input logic [PHYS_BITS-1:0] read_addr0,
    output logic [DATA_BITS-1:0] read_data0,

    input logic [PHYS_BITS-1:0] read_addr1,
    output logic [DATA_BITS-1:0] read_data1,

    input logic [PHYS_BITS-1:0] read_addr2,
    output logic [DATA_BITS-1:0] read_data2,

    input logic [PHYS_BITS-1:0] read_addr3,
    output logic [DATA_BITS-1:0] read_data3,

    input logic write_valid0,
    input logic [PHYS_BITS-1:0] write_addr0,
    input logic [DATA_BITS-1:0] write_data0,

    input logic write_valid1,
    input logic [PHYS_BITS-1:0] write_addr1,
    input logic [DATA_BITS-1:0] write_data1
);

    logic [DATA_BITS-1:0] registers [0:PHYS_REGS-1];

    always_comb begin
        read_data0 = '0;
        read_data1 = '0;
        read_data2 = '0;
        read_data3 = '0;

        if (read_addr0 < PHYS_REGS && read_addr0 != '0)
            read_data0 = registers[read_addr0];

        if (read_addr1 < PHYS_REGS && read_addr1 != '0)
            read_data1 = registers[read_addr1];

        if (read_addr2 < PHYS_REGS && read_addr2 != '0)
            read_data2 = registers[read_addr2];

        if (read_addr3 < PHYS_REGS && read_addr3 != '0)
            read_data3 = registers[read_addr3];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < PHYS_REGS; i = i + 1)
                registers[i] <= '0;
        end else begin
            if (write_valid0 &&
                (write_addr0 != '0) &&
                (write_addr0 < PHYS_REGS))
                registers[write_addr0] <= write_data0;

            if (write_valid1 &&
                (write_addr1 != '0) &&
                (write_addr1 < PHYS_REGS))
                registers[write_addr1] <= write_data1;
        end
    end

endmodule
