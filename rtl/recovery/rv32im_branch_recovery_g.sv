module rv32im_branch_recovery_g #(
    parameter int ADDR_BITS = 32,
    parameter int ROB_TAG_BITS = 5
) (
    input  logic                     resolve_valid,
    input  logic [ROB_TAG_BITS-1:0]  resolve_rob_tag,
    input  logic [ADDR_BITS-1:0]     predicted_next_pc,
    input  logic [ADDR_BITS-1:0]     actual_next_pc,

    output logic                     mispredict,
    output logic                     recovery_valid,
    output logic [ADDR_BITS-1:0]     recovery_pc,
    output logic [ROB_TAG_BITS-1:0]  recovery_rob_tag,

    output logic                     flush_frontend,
    output logic                     flush_decode,
    output logic                     flush_rename,
    output logic                     flush_issue
);

    always_comb begin
        mispredict = 1'b0;
        recovery_valid = 1'b0;
        recovery_pc = '0;
        recovery_rob_tag = '0;

        flush_frontend = 1'b0;
        flush_decode = 1'b0;
        flush_rename = 1'b0;
        flush_issue = 1'b0;

        if (resolve_valid) begin
            if (predicted_next_pc != actual_next_pc) begin
                mispredict = 1'b1;
                recovery_valid = 1'b1;
                recovery_pc = actual_next_pc;
                recovery_rob_tag = resolve_rob_tag;

                flush_frontend = 1'b1;
                flush_decode = 1'b1;
                flush_rename = 1'b1;
                flush_issue = 1'b1;
            end
        end
    end

endmodule