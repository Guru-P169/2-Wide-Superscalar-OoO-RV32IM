module rv32im_exception_controller_g #(
    parameter int ADDR_BITS = 32
) (
    input  logic                  exception_valid,
    input  logic [ADDR_BITS-1:0]   exception_pc,
    input  logic [31:0]           exception_cause,
    input  logic [31:0]           exception_tval,

    input  logic                  interrupt_valid,
    input  logic [ADDR_BITS-1:0]   interrupt_pc,
    input  logic [31:0]           interrupt_cause,

    input  logic                  trap_ready,
    input  logic [ADDR_BITS-1:0]   mtvec,

    output logic                  trap_valid,
    output logic                  trap_is_interrupt,
    output logic [ADDR_BITS-1:0]   trap_pc,
    output logic [31:0]           trap_cause,
    output logic [31:0]           trap_tval,
    output logic [ADDR_BITS-1:0]   trap_vector,
    output logic                  flush_pipeline
);

    always_comb begin
        trap_valid = 1'b0;
        trap_is_interrupt = 1'b0;
        trap_pc = '0;
        trap_cause = '0;
        trap_tval = '0;
        trap_vector = mtvec;
        flush_pipeline = 1'b0;

        if (exception_valid) begin
            trap_valid = 1'b1;
            trap_is_interrupt = 1'b0;
            trap_pc = exception_pc;
            trap_cause = exception_cause;
            trap_tval = exception_tval;
        end
        else if (interrupt_valid) begin
            trap_valid = 1'b1;
            trap_is_interrupt = 1'b1;
            trap_pc = interrupt_pc;
            trap_cause = interrupt_cause;
            trap_tval = '0;
        end

        if (trap_valid && trap_ready) begin
            flush_pipeline = 1'b1;
        end
    end

endmodule