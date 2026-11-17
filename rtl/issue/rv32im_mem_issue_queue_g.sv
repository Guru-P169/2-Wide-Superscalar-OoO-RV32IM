
module rv32im_mem_issue_queue_g #(
    parameter int DEPTH = 8,
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
    input logic enq_is_load0,
    input logic enq_is_store0,
    input logic [1:0] enq_size0,
    input logic enq_unsigned0,
    input logic [PHYS_BITS-1:0] enq_pdst0,
    input logic [PHYS_BITS-1:0] enq_psrc_base0,
    input logic [PHYS_BITS-1:0] enq_psrc_store0,
    input logic [DATA_BITS-1:0] enq_imm0,
    input logic [ROB_BITS-1:0] enq_rob_idx0,
    input logic enq_base_ready0,
    input logic [DATA_BITS-1:0] enq_base_data0,
    input logic enq_store_ready0,
    input logic [DATA_BITS-1:0] enq_store_data0,

    input logic enq_valid1,
    output logic enq_ready1,
    input logic enq_is_load1,
    input logic enq_is_store1,
    input logic [1:0] enq_size1,
    input logic enq_unsigned1,
    input logic [PHYS_BITS-1:0] enq_pdst1,
    input logic [PHYS_BITS-1:0] enq_psrc_base1,
    input logic [PHYS_BITS-1:0] enq_psrc_store1,
    input logic [DATA_BITS-1:0] enq_imm1,
    input logic [ROB_BITS-1:0] enq_rob_idx1,
    input logic enq_base_ready1,
    input logic [DATA_BITS-1:0] enq_base_data1,
    input logic enq_store_ready1,
    input logic [DATA_BITS-1:0] enq_store_data1,

    input logic wakeup_valid0,
    input logic [PHYS_BITS-1:0] wakeup_pdst0,
    input logic [DATA_BITS-1:0] wakeup_data0,

    input logic wakeup_valid1,
    input logic [PHYS_BITS-1:0] wakeup_pdst1,
    input logic [DATA_BITS-1:0] wakeup_data1,

    output logic issue_valid0,
    input logic issue_ready0,
    output logic issue_is_load0,
    output logic issue_is_store0,
    output logic [1:0] issue_size0,
    output logic issue_unsigned0,
    output logic [PHYS_BITS-1:0] issue_pdst0,
    output logic [DATA_BITS-1:0] issue_base0,
    output logic [DATA_BITS-1:0] issue_store_data0,
    output logic [DATA_BITS-1:0] issue_imm0,
    output logic [ROB_BITS-1:0] issue_rob_idx0,

    output logic issue_valid1,
    input logic issue_ready1,
    output logic issue_is_load1,
    output logic issue_is_store1,
    output logic [1:0] issue_size1,
    output logic issue_unsigned1,
    output logic [PHYS_BITS-1:0] issue_pdst1,
    output logic [DATA_BITS-1:0] issue_base1,
    output logic [DATA_BITS-1:0] issue_store_data1,
    output logic [DATA_BITS-1:0] issue_imm1,
    output logic [ROB_BITS-1:0] issue_rob_idx1,

    output logic [COUNT_BITS-1:0] occupancy
);

    logic [DEPTH-1:0] valid;
    logic [DEPTH-1:0] base_ready;
    logic [DEPTH-1:0] store_ready;

    logic [DEPTH-1:0] is_load_mem;
    logic [DEPTH-1:0] is_store_mem;
    logic [DEPTH-1:0] unsigned_mem;

    logic [1:0] size_mem [DEPTH];
    logic [PHYS_BITS-1:0] pdst_mem [DEPTH];
    logic [PHYS_BITS-1:0] psrc_base_mem [DEPTH];
    logic [PHYS_BITS-1:0] psrc_store_mem [DEPTH];
    logic [DATA_BITS-1:0] base_data_mem [DEPTH];
    logic [DATA_BITS-1:0] store_data_mem [DEPTH];
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

    always_comb begin
        free_idx0 = '0;
        free_idx1 = '0;
        found_free0 = 1'b0;
        found_free1 = 1'b0;

        for (int i = 0; i < DEPTH; i = i + 1) begin
            if (!valid[i] && !found_free0) begin
                free_idx0 = PTR_BITS'(i);
                found_free0 = 1'b1;
            end
        end

        for (int i = 0; i < DEPTH; i = i + 1) begin
            if (!valid[i] &&
                !(found_free0 && (PTR_BITS'(i) == free_idx0)) &&
                !found_free1) begin
                free_idx1 = PTR_BITS'(i);
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

        for (int i = 0; i < DEPTH; i = i + 1) begin
            if (valid[i] && base_ready[i] && store_ready[i] &&
                !found_issue0) begin
                selected_idx0 = PTR_BITS'(i);
                found_issue0 = 1'b1;
            end
        end

        for (int i = 0; i < DEPTH; i = i + 1) begin
            if (valid[i] && base_ready[i] && store_ready[i] &&
                !(found_issue0 && (PTR_BITS'(i) == selected_idx0)) &&
                !found_issue1) begin
                selected_idx1 = PTR_BITS'(i);
                found_issue1 = 1'b1;
            end
        end

        issue_valid0 = found_issue0 && !flush;
        issue_valid1 = found_issue1 && !flush;

        issue_is_load0 = 1'b0;
        issue_is_store0 = 1'b0;
        issue_size0 = '0;
        issue_unsigned0 = 1'b0;
        issue_pdst0 = '0;
        issue_base0 = '0;
        issue_store_data0 = '0;
        issue_imm0 = '0;
        issue_rob_idx0 = '0;

        issue_is_load1 = 1'b0;
        issue_is_store1 = 1'b0;
        issue_size1 = '0;
        issue_unsigned1 = 1'b0;
        issue_pdst1 = '0;
        issue_base1 = '0;
        issue_store_data1 = '0;
        issue_imm1 = '0;
        issue_rob_idx1 = '0;

        if (found_issue0) begin
            issue_is_load0 = is_load_mem[selected_idx0];
            issue_is_store0 = is_store_mem[selected_idx0];
            issue_size0 = size_mem[selected_idx0];
            issue_unsigned0 = unsigned_mem[selected_idx0];
            issue_pdst0 = pdst_mem[selected_idx0];
            issue_base0 = base_data_mem[selected_idx0];
            issue_store_data0 = store_data_mem[selected_idx0];
            issue_imm0 = imm_mem[selected_idx0];
            issue_rob_idx0 = rob_mem[selected_idx0];
        end

        if (found_issue1) begin
            issue_is_load1 = is_load_mem[selected_idx1];
            issue_is_store1 = is_store_mem[selected_idx1];
            issue_size1 = size_mem[selected_idx1];
            issue_unsigned1 = unsigned_mem[selected_idx1];
            issue_pdst1 = pdst_mem[selected_idx1];
            issue_base1 = base_data_mem[selected_idx1];
            issue_store_data1 = store_data_mem[selected_idx1];
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
            base_ready <= '0;
            store_ready <= '0;
        end
        else if (flush) begin
            valid <= '0;
            base_ready <= '0;
            store_ready <= '0;
        end
        else begin
            for (int i = 0; i < DEPTH; i = i + 1) begin
                if (valid[i]) begin
                    if (wakeup_valid0 && psrc_base_mem[i] == wakeup_pdst0) begin
                        base_ready[i] <= 1'b1;
                        base_data_mem[i] <= wakeup_data0;
                    end

                    if (wakeup_valid1 && psrc_base_mem[i] == wakeup_pdst1) begin
                        base_ready[i] <= 1'b1;
                        base_data_mem[i] <= wakeup_data1;
                    end

                    if (wakeup_valid0 && psrc_store_mem[i] == wakeup_pdst0) begin
                        store_ready[i] <= 1'b1;
                        store_data_mem[i] <= wakeup_data0;
                    end

                    if (wakeup_valid1 && psrc_store_mem[i] == wakeup_pdst1) begin
                        store_ready[i] <= 1'b1;
                        store_data_mem[i] <= wakeup_data1;
                    end
                end
            end

            if (pop0)
                valid[selected_idx0] <= 1'b0;

            if (pop1)
                valid[selected_idx1] <= 1'b0;

            if (push0) begin
                valid[free_idx0] <= 1'b1;
                is_load_mem[free_idx0] <= enq_is_load0;
                is_store_mem[free_idx0] <= enq_is_store0;
                size_mem[free_idx0] <= enq_size0;
                unsigned_mem[free_idx0] <= enq_unsigned0;
                pdst_mem[free_idx0] <= enq_pdst0;
                psrc_base_mem[free_idx0] <= enq_psrc_base0;
                psrc_store_mem[free_idx0] <= enq_psrc_store0;
                base_data_mem[free_idx0] <= enq_base_data0;
                store_data_mem[free_idx0] <= enq_store_data0;
                imm_mem[free_idx0] <= enq_imm0;
                rob_mem[free_idx0] <= enq_rob_idx0;
                base_ready[free_idx0] <= enq_base_ready0;
                store_ready[free_idx0] <= enq_store_ready0;
            end

            if (push1) begin
                valid[free_idx1] <= 1'b1;
                is_load_mem[free_idx1] <= enq_is_load1;
                is_store_mem[free_idx1] <= enq_is_store1;
                size_mem[free_idx1] <= enq_size1;
                unsigned_mem[free_idx1] <= enq_unsigned1;
                pdst_mem[free_idx1] <= enq_pdst1;
                psrc_base_mem[free_idx1] <= enq_psrc_base1;
                psrc_store_mem[free_idx1] <= enq_psrc_store1;
                base_data_mem[free_idx1] <= enq_base_data1;
                store_data_mem[free_idx1] <= enq_store_data1;
                imm_mem[free_idx1] <= enq_imm1;
                rob_mem[free_idx1] <= enq_rob_idx1;
                base_ready[free_idx1] <= enq_base_ready1;
                store_ready[free_idx1] <= enq_store_ready1;
            end
        end
    end

endmodule
