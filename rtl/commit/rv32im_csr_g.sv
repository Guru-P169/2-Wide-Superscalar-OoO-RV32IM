module rv32im_csr_g #(
    parameter int ADDR_BITS = 12,
    parameter int DATA_BITS = 32
) (
    input logic clk,
    input logic rst_n,

    input logic read_valid,
    input logic [ADDR_BITS-1:0] read_addr,
    output logic [DATA_BITS-1:0] read_data,

    input logic write_valid,
    input logic [ADDR_BITS-1:0] write_addr,
    input logic [DATA_BITS-1:0] write_data,
    input logic [2:0] write_cmd,

    input logic trap_valid,
    input logic [DATA_BITS-1:0] trap_pc,
    input logic [DATA_BITS-1:0] trap_cause,
    input logic [DATA_BITS-1:0] trap_value,
    input logic mret,
    input logic [1:0] retire_count,

    input logic [DATA_BITS-1:0] external_interrupts,
    output logic [DATA_BITS-1:0] trap_vector,
    output logic [DATA_BITS-1:0] exception_pc,
    output logic global_interrupt_enable
);

    localparam logic [ADDR_BITS-1:0] CSR_MSTATUS = 12'h300;
    localparam logic [ADDR_BITS-1:0] CSR_MIE = 12'h304;
    localparam logic [ADDR_BITS-1:0] CSR_MTVEC = 12'h305;
    localparam logic [ADDR_BITS-1:0] CSR_MSCRATCH = 12'h340;
    localparam logic [ADDR_BITS-1:0] CSR_MEPC = 12'h341;
    localparam logic [ADDR_BITS-1:0] CSR_MCAUSE = 12'h342;
    localparam logic [ADDR_BITS-1:0] CSR_MTVAL = 12'h343;
    localparam logic [ADDR_BITS-1:0] CSR_MIP = 12'h344;
    localparam logic [ADDR_BITS-1:0] CSR_MCYCLE = 12'hB00;
    localparam logic [ADDR_BITS-1:0] CSR_MINSTRET = 12'hB02;
    localparam logic [ADDR_BITS-1:0] CSR_MCYCLEH = 12'hB80;
    localparam logic [ADDR_BITS-1:0] CSR_MINSTRETH = 12'hB82;
    localparam logic [ADDR_BITS-1:0] CSR_CYCLE = 12'hC00;
    localparam logic [ADDR_BITS-1:0] CSR_INSTRET = 12'hC02;
    localparam logic [ADDR_BITS-1:0] CSR_CYCLEH = 12'hC80;
    localparam logic [ADDR_BITS-1:0] CSR_INSTRETH = 12'hC82;

    logic [DATA_BITS-1:0] mstatus;
    logic [DATA_BITS-1:0] mie;
    logic [DATA_BITS-1:0] mtvec;
    logic [DATA_BITS-1:0] mepc;
    logic [DATA_BITS-1:0] mcause;
    logic [DATA_BITS-1:0] mscratch;
    logic [DATA_BITS-1:0] mtval;
    logic [DATA_BITS-1:0] mip;
    logic [2*DATA_BITS-1:0] mcycle;
    logic [2*DATA_BITS-1:0] minstret;

    logic [DATA_BITS-1:0] old_value;
    logic [DATA_BITS-1:0] write_result;

    always_comb begin
        case (read_addr)
            CSR_MSTATUS: read_data = mstatus;
            CSR_MIE: read_data = mie;
            CSR_MTVEC: read_data = mtvec;
            CSR_MSCRATCH: read_data = mscratch;
            CSR_MEPC: read_data = mepc;
            CSR_MCAUSE: read_data = mcause;
            CSR_MTVAL: read_data = mtval;
            CSR_MIP: read_data = mip;
            CSR_MCYCLE, CSR_CYCLE: read_data = mcycle[DATA_BITS-1:0];
            CSR_MCYCLEH, CSR_CYCLEH: read_data = mcycle[2*DATA_BITS-1:DATA_BITS];
            CSR_MINSTRET, CSR_INSTRET: read_data = minstret[DATA_BITS-1:0];
            CSR_MINSTRETH, CSR_INSTRETH: read_data = minstret[2*DATA_BITS-1:DATA_BITS];
            default: read_data = '0;
        endcase

        old_value = '0;

        case (write_addr)
            CSR_MSTATUS: old_value = mstatus;
            CSR_MIE: old_value = mie;
            CSR_MTVEC: old_value = mtvec;
            CSR_MSCRATCH: old_value = mscratch;
            CSR_MEPC: old_value = mepc;
            CSR_MCAUSE: old_value = mcause;
            CSR_MTVAL: old_value = mtval;
            CSR_MIP: old_value = mip;
            CSR_MCYCLE, CSR_CYCLE: old_value = mcycle[DATA_BITS-1:0];
            CSR_MCYCLEH, CSR_CYCLEH: old_value = mcycle[2*DATA_BITS-1:DATA_BITS];
            CSR_MINSTRET, CSR_INSTRET: old_value = minstret[DATA_BITS-1:0];
            CSR_MINSTRETH, CSR_INSTRETH: old_value = minstret[2*DATA_BITS-1:DATA_BITS];
            default: old_value = '0;
        endcase

        case (write_cmd)
            3'b001: write_result = write_data;
            3'b010: write_result = old_value | write_data;
            3'b011: write_result = old_value & ~write_data;
            default: write_result = old_value;
        endcase

        trap_vector = {mtvec[DATA_BITS-1:2], 2'b00};
        exception_pc = mepc;
        global_interrupt_enable = mstatus[3];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= '0;
            mie <= '0;
            mtvec <= '0;
            mscratch <= '0;
            mepc <= '0;
            mcause <= '0;
            mtval <= '0;
            mip <= '0;
            mcycle <= '0;
            minstret <= '0;
        end else begin
            mcycle <= mcycle + 1'b1;
            minstret <= minstret + {{(2*DATA_BITS-2){1'b0}}, retire_count};
            mip <= external_interrupts;

            if (write_valid) begin
                case (write_addr)
                    CSR_MSTATUS: mstatus <= write_result;
                    CSR_MIE: mie <= write_result;
                    CSR_MTVEC: mtvec <= {write_result[DATA_BITS-1:2], 2'b00};
                    CSR_MSCRATCH: mscratch <= write_result;
                    CSR_MEPC: mepc <= {write_result[DATA_BITS-1:2], 2'b00};
                    CSR_MCAUSE: mcause <= write_result;
                    CSR_MTVAL: mtval <= write_result;
                    CSR_MIP: mip <= write_result;
                    CSR_MCYCLE: mcycle[DATA_BITS-1:0] <= write_result;
                    CSR_MCYCLEH: mcycle[2*DATA_BITS-1:DATA_BITS] <= write_result;
                    CSR_MINSTRET: minstret[DATA_BITS-1:0] <= write_result;
                    CSR_MINSTRETH: minstret[2*DATA_BITS-1:DATA_BITS] <= write_result;
                    default: begin
                    end
                endcase
            end

            if (trap_valid) begin
                mepc <= {trap_pc[DATA_BITS-1:2], 2'b00};
                mcause <= trap_cause;
                mtval <= trap_value;
                mstatus[7] <= mstatus[3];
                mstatus[3] <= 1'b0;
            end else if (mret) begin
                mstatus[3] <= mstatus[7];
                mstatus[7] <= 1'b1;
            end
        end
    end

endmodule