
module rv32im_issue_select_g #(
    parameter int DEPTH = 8,
    parameter int PTR_BITS = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input logic [DEPTH-1:0] entry_valid,
    input logic [DEPTH-1:0] src1_ready,
    input logic [DEPTH-1:0] src2_ready,

    output logic issue_valid0,
    output logic [PTR_BITS-1:0] issue_idx0,

    output logic issue_valid1,
    output logic [PTR_BITS-1:0] issue_idx1
);

    logic [DEPTH-1:0] ready_entries;
    logic found0;
    logic found1;

    always_comb begin
        ready_entries = entry_valid & src1_ready & src2_ready;

        issue_valid0 = 1'b0;
        issue_valid1 = 1'b0;
        issue_idx0 = '0;
        issue_idx1 = '0;

        found0 = 1'b0;
        found1 = 1'b0;

        for (int i = 0; i < DEPTH; i = i + 1) begin
            if (ready_entries[i] && !found0) begin
                issue_valid0 = 1'b1;
                issue_idx0 = PTR_BITS'(i);
                found0 = 1'b1;
            end
            else if (ready_entries[i] && !found1) begin
                issue_valid1 = 1'b1;
                issue_idx1 = PTR_BITS'(i);
                found1 = 1'b1;
            end
        end
    end

endmodule
