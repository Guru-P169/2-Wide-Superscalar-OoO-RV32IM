
module rv32im_int_issue_queue_g #(
    parameter int DEPTH = 8,
    parameter int OP_BITS = 5,
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32,
    parameter int ROB_BITS = 5,
    parameter int PTR_BITS = (DEPTH > 1) ? $clog2(DEPTH) : 1,
    parameter int COUNT_BITS = $clog2(DEPTH + 1)
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic enq_valid0,
    output logic enq_ready0,
    input logic [OP_BITS-1:0] enq_op0,
    input logic [PHYS_BITS-1:0] enq_pdst0,
    input logic [PHYS_BITS-1:0] enq_psrc1_0,
    input logic [PHYS_BITS-1:0] enq_psrc2_0,
    input logic [DATA_BITS-1:0] enq_imm0,
    input logic [ROB_BITS-1:0] enq_rob_idx0,
    input logic enq_src1_ready0,
    input logic [DATA_BITS-1:0] enq_src1_data0,
    input logic enq_src2_ready0,
    input logic [DATA_BITS-1:0] enq_src2_data0,

    input logic enq_valid1,
    output logic enq_ready1,
    input logic [OP_BITS-1:0] enq_op1,
    input logic [PHYS_BITS-1:0] enq_pdst1,
    input logic [PHYS_BITS-1:0] enq_psrc1_1,
    input logic [PHYS_BITS-1:0] enq_psrc2_1,
    input logic [DATA_BITS-1:0] enq_imm1,
    input logic [ROB_BITS-1:0] enq_rob_idx1,
    input logic enq_src1_ready1,
    input logic [DATA_BITS-1:0] enq_src1_data1,
    input logic enq_src2_ready1,
    input logic [DATA_BITS-1:0] enq_src2_data1,

    input logic wakeup_valid0,
    input logic [PHYS_BITS-1:0] wakeup_pdst0,
    input logic [DATA_BITS-1:0] wakeup_data0,

    input logic wakeup_valid1,
    input logic [PHYS_BITS-1:0] wakeup_pdst1,
    input logic [DATA_BITS-1:0] wakeup_data1,

    output logic issue_valid0,
    input logic issue_ready0,
    output logic [OP_BITS-1:0] issue_op0,
    output logic [PHYS_BITS-1:0] issue_pdst0,
    output logic [DATA_BITS-1:0] issue_src1_0,
    output logic [DATA_BITS-1:0] issue_src2_0,
    output logic [DATA_BITS-1:0] issue_imm0,
    output logic [ROB_BITS-1:0] issue_rob_idx0,

    output logic issue_valid1,
    input logic issue_ready1,
    output logic [OP_BITS-1:0] issue_op1,
    output logic [PHYS_BITS-1:0] issue_pdst1,
    output logic [DATA_BITS-1:0] issue_src1_1,
    output logic [DATA_BITS-1:0] issue_src2_1,
    output logic [DATA_BITS-1:0] issue_imm1,
    output logic [ROB_BITS-1:0] issue_rob_idx1,

    output logic [COUNT_BITS-1:0] occupancy
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

    logic [PTR_BITS-1:0] free_idx0;
    logic [PTR_BITS-1:0] free_idx1;
    logic [PTR_BITS-1:0] selected_idx0;
    logic [PTR_BITS-1:0] selected_idx1;

    logic found_free0;
    logic found_free1;
    logic found_issue0;
    logic found_issue1;

    logic push0;
    logic push1;
    logic pop0;
    logic pop1;

    integer i;

    always_comb begin
        free_idx0 = '0;
        free_idx1 = '0;
        found_free0 = 1'b0;
        found_free1 = 1'b0;

        for (int j = 0; j < DEPTH; j = j + 1) begin
            if (!valid[j] && !found_free0) begin
                free_idx0 = PTR_BITS'(j);
                found_free0 = 1'b1;
            end
        end

        for (int j = 0; j < DEPTH; j = j + 1) begin
            if (!valid[j] && !(found_free0 && (PTR_BITS'(j) == free_idx0)) && !found_free1) begin
                free_idx1 = PTR_BITS'(j);
                found_free1 = 1'b1;
            end
        end

        enq_ready0 = found_free0 && !flush;
        enq_ready1 = found_free1 && !flush && enq_ready0;

        push0 = enq_valid0 && enq_ready0;
        push1 = enq_valid1 && enq_ready1 && push0;

        selected_idx0 = '0;
        selected_idx1 = '0;
        found_issue0 = 1'b0;
        found_issue1 = 1'b0;

        for (int j = 0; j < DEPTH; j = j + 1) begin
            if (valid[j] && src1_ready[j] && src2_ready[j] && !found_issue0) begin
                selected_idx0 = PTR_BITS'(j);
                found_issue0 = 1'b1;
            end
        end

        for (int j = 0; j < DEPTH; j = j + 1) begin
            if (valid[j] && src1_ready[j] && src2_ready[j] &&
                !(found_issue0 && (PTR_BITS'(j) == selected_idx0)) &&
                !found_issue1) begin
                selected_idx1 = PTR_BITS'(j);
                found_issue1 = 1'b1;
            end
        end

        issue_valid0 = found_issue0 && !flush;
        issue_valid1 = found_issue1 && !flush;

        issue_op0 = '0;
        issue_pdst0 = '0;
        issue_src1_0 = '0;
        issue_src2_0 = '0;
        issue_imm0 = '0;
        issue_rob_idx0 = '0;

        issue_op1 = '0;
        issue_pdst1 = '0;
        issue_src1_1 = '0;
        issue_src2_1 = '0;
        issue_imm1 = '0;
        issue_rob_idx1 = '0;

        if (found_issue0) begin
            issue_op0 = op_mem[selected_idx0];
            issue_pdst0 = pdst_mem[selected_idx0];
            issue_src1_0 = src1_data_mem[selected_idx0];
            issue_src2_0 = src2_data_mem[selected_idx0];
            issue_imm0 = imm_mem[selected_idx0];
            issue_rob_idx0 = rob_mem[selected_idx0];
        end

        if (found_issue1) begin
            issue_op1 = op_mem[selected_idx1];
            issue_pdst1 = pdst_mem[selected_idx1];
            issue_src1_1 = src1_data_mem[selected_idx1];
            issue_src2_1 = src2_data_mem[selected_idx1];
            issue_imm1 = imm_mem[selected_idx1];
            issue_rob_idx1 = rob_mem[selected_idx1];
        end

        pop0 = issue_valid0 && issue_ready0;
        pop1 = issue_valid1 && issue_ready1;

        occupancy = COUNT_BITS'($countones(valid));
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= '0;
            src1_ready <= '0;
            src2_ready <= '0;
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

            if (pop0)
                valid[selected_idx0] <= 1'b0;

            if (pop1)
                valid[selected_idx1] <= 1'b0;

            if (push0) begin
                valid[free_idx0] <= 1'b1;
                op_mem[free_idx0] <= enq_op0;
                pdst_mem[free_idx0] <= enq_pdst0;
                psrc1_mem[free_idx0] <= enq_psrc1_0;
                psrc2_mem[free_idx0] <= enq_psrc2_0;
                imm_mem[free_idx0] <= enq_imm0;
                rob_mem[free_idx0] <= enq_rob_idx0;
                src1_ready[free_idx0] <= enq_src1_ready0;
                src2_ready[free_idx0] <= enq_src2_ready0;
                src1_data_mem[free_idx0] <= enq_src1_data0;
                src2_data_mem[free_idx0] <= enq_src2_data0;
            end

            if (push1) begin
                valid[free_idx1] <= 1'b1;
                op_mem[free_idx1] <= enq_op1;
                pdst_mem[free_idx1] <= enq_pdst1;
                psrc1_mem[free_idx1] <= enq_psrc1_1;
                psrc2_mem[free_idx1] <= enq_psrc2_1;
                imm_mem[free_idx1] <= enq_imm1;
                rob_mem[free_idx1] <= enq_rob_idx1;
                src1_ready[free_idx1] <= enq_src1_ready1;
                src2_ready[free_idx1] <= enq_src2_ready1;
                src1_data_mem[free_idx1] <= enq_src1_data1;
                src2_data_mem[free_idx1] <= enq_src2_data1;
            end
        end
    end

endmodule
