
module rv32im_issue_queue_g #(
    parameter int DEPTH = 8,
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32,
    parameter int ROB_BITS = 5,
    parameter int OP_BITS = 5,
    parameter int PTR_BITS = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic enq_valid,
    output logic enq_ready,
    input logic [OP_BITS-1:0] enq_op,
    input logic [PHYS_BITS-1:0] enq_pdst,
    input logic [PHYS_BITS-1:0] enq_psrc1,
    input logic [PHYS_BITS-1:0] enq_psrc2,
    input logic [DATA_BITS-1:0] enq_imm,
    input logic [ROB_BITS-1:0] enq_rob_idx,

    input logic [PHYS_BITS-1:0] wakeup_pdst0,
    input logic wakeup_valid0,
    input logic [DATA_BITS-1:0] wakeup_data0,

    input logic [PHYS_BITS-1:0] wakeup_pdst1,
    input logic wakeup_valid1,
    input logic [DATA_BITS-1:0] wakeup_data1,

    output logic issue_valid,
    input logic issue_ready,
    output logic [OP_BITS-1:0] issue_op,
    output logic [PHYS_BITS-1:0] issue_pdst,
    output logic [DATA_BITS-1:0] issue_src1,
    output logic [DATA_BITS-1:0] issue_src2,
    output logic [DATA_BITS-1:0] issue_imm,
    output logic [ROB_BITS-1:0] issue_rob_idx,

    output logic [$clog2(DEPTH+1)-1:0] occupancy
);

    logic [DEPTH-1:0] valid;
    logic [DEPTH-1:0] src1_ready;
    logic [DEPTH-1:0] src2_ready;

    logic [OP_BITS-1:0] op_mem [DEPTH];
    logic [PHYS_BITS-1:0] pdst_mem [DEPTH];
    logic [PHYS_BITS-1:0] psrc1_mem [DEPTH];
    logic [PHYS_BITS-1:0] psrc2_mem [DEPTH];
    logic [DATA_BITS-1:0] src1_data_mem [DEPTH];
    logic [DATA_BITS-1:0] src2_data_mem [DEPTH];
    logic [DATA_BITS-1:0] imm_mem [DEPTH];
    logic [ROB_BITS-1:0] rob_mem [DEPTH];

    logic [PTR_BITS-1:0] insert_idx;
    logic [PTR_BITS-1:0] selected_idx;
    logic [PTR_BITS-1:0] free_idx;
    logic found_ready;
    logic found_free;

    integer i;

    always_comb begin
        enq_ready = 1'b0;
        free_idx = '0;
        found_free = 1'b0;

        for (int j = 0; j < DEPTH; j = j + 1) begin
            if (!valid[j] && !found_free) begin
                free_idx = PTR_BITS'(j);
                found_free = 1'b1;
            end
        end

        enq_ready = found_free && !flush;

        selected_idx = '0;
        found_ready = 1'b0;

        for (int j = 0; j < DEPTH; j = j + 1) begin
            if (valid[j] && src1_ready[j] && src2_ready[j] && !found_ready) begin
                selected_idx = PTR_BITS'(j);
                found_ready = 1'b1;
            end
        end

        issue_valid = found_ready && !flush;
        issue_op = '0;
        issue_pdst = '0;
        issue_src1 = '0;
        issue_src2 = '0;
        issue_imm = '0;
        issue_rob_idx = '0;

        if (found_ready) begin
            issue_op = op_mem[selected_idx];
            issue_pdst = pdst_mem[selected_idx];
            issue_src1 = src1_data_mem[selected_idx];
            issue_src2 = src2_data_mem[selected_idx];
            issue_imm = imm_mem[selected_idx];
            issue_rob_idx = rob_mem[selected_idx];
        end

        occupancy = $clog2(DEPTH+1)'($countones(valid));
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= '0;
            src1_ready <= '0;
            src2_ready <= '0;
            insert_idx <= '0;
        end
        else if (flush) begin
            valid <= '0;
            src1_ready <= '0;
            src2_ready <= '0;
        end
        else begin
            for (int j = 0; j < DEPTH; j = j + 1) begin
                if (valid[j]) begin
                    if (wakeup_valid0 && psrc1_mem[j] == wakeup_pdst0) begin
                        src1_ready[j] <= 1'b1;
                        src1_data_mem[j] <= wakeup_data0;
                    end

                    if (wakeup_valid1 && psrc1_mem[j] == wakeup_pdst1) begin
                        src1_ready[j] <= 1'b1;
                        src1_data_mem[j] <= wakeup_data1;
                    end

                    if (wakeup_valid0 && psrc2_mem[j] == wakeup_pdst0) begin
                        src2_ready[j] <= 1'b1;
                        src2_data_mem[j] <= wakeup_data0;
                    end

                    if (wakeup_valid1 && psrc2_mem[j] == wakeup_pdst1) begin
                        src2_ready[j] <= 1'b1;
                        src2_data_mem[j] <= wakeup_data1;
                    end
                end
            end

            if (issue_valid && issue_ready) begin
                valid[selected_idx] <= 1'b0;
            end

            if (enq_valid && enq_ready) begin
                valid[free_idx] <= 1'b1;
                op_mem[free_idx] <= enq_op;
                pdst_mem[free_idx] <= enq_pdst;
                psrc1_mem[free_idx] <= enq_psrc1;
                psrc2_mem[free_idx] <= enq_psrc2;
                imm_mem[free_idx] <= enq_imm;
                rob_mem[free_idx] <= enq_rob_idx;

                src1_ready[free_idx] <= (enq_psrc1 == '0);
                src2_ready[free_idx] <= (enq_psrc2 == '0);
                src1_data_mem[free_idx] <= '0;
                src2_data_mem[free_idx] <= '0;
            end
        end
    end

endmodule
