module rv32im_recovery_controller_g #(
    parameter int ADDR_BITS = 32,
    parameter int ROB_TAG_BITS = 5
) (
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    branch_recovery_valid,
    input  logic [ADDR_BITS-1:0]    branch_recovery_pc,
    input  logic [ROB_TAG_BITS-1:0] branch_recovery_rob_tag,

    input  logic                    exception_valid,
    input  logic [ADDR_BITS-1:0]    exception_pc,

    input  logic                    interrupt_valid,
    input  logic [ADDR_BITS-1:0]    interrupt_pc,

    output logic                    recovery_valid,
    output logic [ADDR_BITS-1:0]    recovery_pc,
    output logic                    recovery_is_branch,
    output logic                    recovery_is_exception,
    output logic                    recovery_is_interrupt,
    output logic [ROB_TAG_BITS-1:0] recovery_rob_tag,

    output logic                    flush_frontend,
    output logic                    flush_decode,
    output logic                    flush_rename,
    output logic                    flush_issue,
    output logic                    flush_pipeline
);

    always_comb begin
        recovery_valid = 1'b0;
        recovery_pc = '0;
        recovery_is_branch = 1'b0;
        recovery_is_exception = 1'b0;
        recovery_is_interrupt = 1'b0;
        recovery_rob_tag = '0;

        flush_frontend = 1'b0;
        flush_decode = 1'b0;
        flush_rename = 1'b0;
        flush_issue = 1'b0;
        flush_pipeline = 1'b0;

        if (exception_valid) begin
            recovery_valid = 1'b1;
            recovery_pc = exception_pc;
            recovery_is_exception = 1'b1;
        end
        else if (interrupt_valid) begin
            recovery_valid = 1'b1;
            recovery_pc = interrupt_pc;
            recovery_is_interrupt = 1'b1;
        end
        else if (branch_recovery_valid) begin
            recovery_valid = 1'b1;
            recovery_pc = branch_recovery_pc;
            recovery_is_branch = 1'b1;
            recovery_rob_tag = branch_recovery_rob_tag;
        end

        if (recovery_valid) begin
            flush_frontend = 1'b1;
            flush_decode = 1'b1;
            flush_rename = 1'b1;
            flush_issue = 1'b1;
            flush_pipeline = 1'b1;
        end
    end

endmodule