
module rv32im_rob_g #(
    parameter int DEPTH = 32,
    parameter int ROB_BITS = (DEPTH > 1) ? $clog2(DEPTH) : 1,
    parameter int PC_BITS = 32,
    parameter int ARCH_BITS = 5,
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic dispatch_valid0,
    output logic dispatch_ready0,
    input logic [PC_BITS-1:0] dispatch_pc0,
    input logic [ARCH_BITS-1:0] dispatch_rd0,
    input logic [PHYS_BITS-1:0] dispatch_pdst0,
    input logic [PHYS_BITS-1:0] dispatch_old_pdst0,
    input logic dispatch_writes_rd0,

    input logic dispatch_valid1,
    output logic dispatch_ready1,
    input logic [PC_BITS-1:0] dispatch_pc1,
    input logic [ARCH_BITS-1:0] dispatch_rd1,
    input logic [PHYS_BITS-1:0] dispatch_pdst1,
    input logic [PHYS_BITS-1:0] dispatch_old_pdst1,
    input logic dispatch_writes_rd1,

    input logic complete_valid0,
    input logic [ROB_BITS-1:0] complete_idx0,
    input logic [DATA_BITS-1:0] complete_data0,
    input logic complete_exception0,
    input logic [DATA_BITS-1:0] complete_cause0,

    input logic complete_valid1,
    input logic [ROB_BITS-1:0] complete_idx1,
    input logic [DATA_BITS-1:0] complete_data1,
    input logic complete_exception1,
    input logic [DATA_BITS-1:0] complete_cause1,

    output logic commit_valid0,
    input logic commit_ready0,
    output logic [ROB_BITS-1:0] commit_idx0,
    output logic [PC_BITS-1:0] commit_pc0,
    output logic [ARCH_BITS-1:0] commit_rd0,
    output logic [PHYS_BITS-1:0] commit_pdst0,
    output logic [PHYS_BITS-1:0] commit_old_pdst0,
    output logic [DATA_BITS-1:0] commit_data0,
    output logic commit_writes_rd0,
    output logic commit_exception0,
    output logic [DATA_BITS-1:0] commit_cause0,

    output logic commit_valid1,
    input logic commit_ready1,
    output logic [ROB_BITS-1:0] commit_idx1,
    output logic [PC_BITS-1:0] commit_pc1,
    output logic [ARCH_BITS-1:0] commit_rd1,
    output logic [PHYS_BITS-1:0] commit_pdst1,
    output logic [PHYS_BITS-1:0] commit_old_pdst1,
    output logic [DATA_BITS-1:0] commit_data1,
    output logic commit_writes_rd1,
    output logic commit_exception1,
    output logic [DATA_BITS-1:0] commit_cause1,

    output logic [$clog2(DEPTH+1)-1:0] occupancy,
    output logic empty,
    output logic full
);

    typedef struct packed {
        logic valid;
        logic done;
        logic [PC_BITS-1:0] pc;
        logic [ARCH_BITS-1:0] rd;
        logic [PHYS_BITS-1:0] pdst;
        logic [PHYS_BITS-1:0] old_pdst;
        logic writes_rd;
        logic [DATA_BITS-1:0] data;
        logic exception;
        logic [DATA_BITS-1:0] cause;
    } rob_entry_t;

    localparam int COUNT_BITS = $clog2(DEPTH + 1);

    rob_entry_t entries [0:DEPTH-1];

    logic [ROB_BITS-1:0] head;
    logic [ROB_BITS-1:0] tail;

    logic push0;
    logic push1;
    logic pop0;
    logic pop1;

    logic [COUNT_BITS-1:0] push_count;
    logic [COUNT_BITS-1:0] pop_count;
    logic [COUNT_BITS-1:0] occupancy_next;

    logic [ROB_BITS-1:0] head_next;
    logic [ROB_BITS-1:0] tail_next;

    function automatic logic [ROB_BITS-1:0] next_ptr(
        input logic [ROB_BITS-1:0] ptr
    );
        if (ptr == ROB_BITS'(DEPTH - 1))
            next_ptr = '0;
        else
            next_ptr = ptr + 1'b1;
    endfunction

    always_comb begin
        empty = occupancy == '0;
        full = occupancy == COUNT_BITS'(DEPTH);

        dispatch_ready0 = !flush &&
                          (occupancy <= COUNT_BITS'(DEPTH - 1));

        dispatch_ready1 = !flush &&
                          dispatch_valid0 &&
                          dispatch_ready0 &&
                          (occupancy <= COUNT_BITS'(DEPTH - 2));

        push0 = dispatch_valid0 && dispatch_ready0;
        push1 = dispatch_valid1 && dispatch_ready1;

        commit_valid0 = !flush &&
                        !empty &&
                        entries[head].valid &&
                        entries[head].done;

        commit_valid1 = 1'b0;

        if (occupancy > COUNT_BITS'(1) && commit_valid0) begin
            if (entries[next_ptr(head)].valid &&
                entries[next_ptr(head)].done)
                commit_valid1 = 1'b1;
        end

        commit_idx0 = head;
        commit_pc0 = entries[head].pc;
        commit_rd0 = entries[head].rd;
        commit_pdst0 = entries[head].pdst;
        commit_old_pdst0 = entries[head].old_pdst;
        commit_data0 = entries[head].data;
        commit_writes_rd0 = entries[head].writes_rd;
        commit_exception0 = entries[head].exception;
        commit_cause0 = entries[head].cause;

        commit_idx1 = next_ptr(head);
        commit_pc1 = entries[next_ptr(head)].pc;
        commit_rd1 = entries[next_ptr(head)].rd;
        commit_pdst1 = entries[next_ptr(head)].pdst;
        commit_old_pdst1 = entries[next_ptr(head)].old_pdst;
        commit_data1 = entries[next_ptr(head)].data;
        commit_writes_rd1 = entries[next_ptr(head)].writes_rd;
        commit_exception1 = entries[next_ptr(head)].exception;
        commit_cause1 = entries[next_ptr(head)].cause;

        pop0 = commit_valid0 && commit_ready0;
        pop1 = pop0 && commit_valid1 && commit_ready1;

        push_count = {COUNT_BITS{1'b0}} +
                     COUNT_BITS'(push0) +
                     COUNT_BITS'(push1);

        pop_count = {COUNT_BITS{1'b0}} +
                    COUNT_BITS'(pop0) +
                    COUNT_BITS'(pop1);

        occupancy_next = occupancy + push_count - pop_count;

        head_next = head;
        tail_next = tail;

        if (pop0)
            head_next = next_ptr(head);

        if (pop1)
            head_next = next_ptr(head_next);

        if (push0)
            tail_next = next_ptr(tail);

        if (push1)
            tail_next = next_ptr(tail_next);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head <= '0;
            tail <= '0;
            occupancy <= '0;

            for (int i = 0; i < DEPTH; i = i + 1)
                entries[i] <= '0;
        end else if (flush) begin
            head <= '0;
            tail <= '0;
            occupancy <= '0;

            for (int i = 0; i < DEPTH; i = i + 1)
                entries[i] <= '0;
        end else begin
            head <= head_next;
            tail <= tail_next;
            occupancy <= occupancy_next;

            if (push0) begin
                entries[tail].valid <= 1'b1;
                entries[tail].done <= 1'b0;
                entries[tail].pc <= dispatch_pc0;
                entries[tail].rd <= dispatch_rd0;
                entries[tail].pdst <= dispatch_pdst0;
                entries[tail].old_pdst <= dispatch_old_pdst0;
                entries[tail].writes_rd <= dispatch_writes_rd0;
                entries[tail].data <= '0;
                entries[tail].exception <= 1'b0;
                entries[tail].cause <= '0;
            end

            if (push1) begin
                entries[next_ptr(tail)].valid <= 1'b1;
                entries[next_ptr(tail)].done <= 1'b0;
                entries[next_ptr(tail)].pc <= dispatch_pc1;
                entries[next_ptr(tail)].rd <= dispatch_rd1;
                entries[next_ptr(tail)].pdst <= dispatch_pdst1;
                entries[next_ptr(tail)].old_pdst <= dispatch_old_pdst1;
                entries[next_ptr(tail)].writes_rd <= dispatch_writes_rd1;
                entries[next_ptr(tail)].data <= '0;
                entries[next_ptr(tail)].exception <= 1'b0;
                entries[next_ptr(tail)].cause <= '0;
            end

            if (complete_valid0 && entries[complete_idx0].valid) begin
                entries[complete_idx0].done <= 1'b1;
                entries[complete_idx0].data <= complete_data0;
                entries[complete_idx0].exception <= complete_exception0;
                entries[complete_idx0].cause <= complete_cause0;
            end

            if (complete_valid1 && entries[complete_idx1].valid) begin
                entries[complete_idx1].done <= 1'b1;
                entries[complete_idx1].data <= complete_data1;
                entries[complete_idx1].exception <= complete_exception1;
                entries[complete_idx1].cause <= complete_cause1;
            end

            if (pop0)
                entries[head].valid <= 1'b0;

            if (pop1)
                entries[next_ptr(head)].valid <= 1'b0;
        end
    end

endmodule
