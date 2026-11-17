
module rv32im_fetch_queue_g #(
    parameter int QUEUE_DEPTH = 8,
    parameter int GHR_BITS = 4
) (
    input logic clk,
    input logic rst_n,

    input logic flush,

    input logic in_valid0,
    input logic [31:0] in_pc0,
    input logic [31:0] in_instruction0,
    input logic in_predicted_taken0,
    input logic [31:0] in_predicted_target0,
    input logic [GHR_BITS-1:0] in_history_snapshot0,
    output logic in_ready0,

    input logic in_valid1,
    input logic [31:0] in_pc1,
    input logic [31:0] in_instruction1,
    input logic in_predicted_taken1,
    input logic [31:0] in_predicted_target1,
    input logic [GHR_BITS-1:0] in_history_snapshot1,
    output logic in_ready1,

    output logic out_valid0,
    output logic [31:0] out_pc0,
    output logic [31:0] out_instruction0,
    output logic out_predicted_taken0,
    output logic [31:0] out_predicted_target0,
    output logic [GHR_BITS-1:0] out_history_snapshot0,
    input logic out_ready0,

    output logic out_valid1,
    output logic [31:0] out_pc1,
    output logic [31:0] out_instruction1,
    output logic out_predicted_taken1,
    output logic [31:0] out_predicted_target1,
    output logic [GHR_BITS-1:0] out_history_snapshot1,
    input logic out_ready1,

    output logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count
);

    localparam int PTR_BITS =
        (QUEUE_DEPTH > 1) ? $clog2(QUEUE_DEPTH) : 1;

    localparam int COUNT_BITS = $clog2(QUEUE_DEPTH + 1);

    logic [31:0] pc_mem [0:QUEUE_DEPTH-1];
    logic [31:0] instruction_mem [0:QUEUE_DEPTH-1];
    logic predicted_taken_mem [0:QUEUE_DEPTH-1];
    logic [31:0] predicted_target_mem [0:QUEUE_DEPTH-1];
    logic [GHR_BITS-1:0] history_snapshot_mem [0:QUEUE_DEPTH-1];

    logic [PTR_BITS-1:0] read_ptr;
    logic [PTR_BITS-1:0] write_ptr;

    logic pop0;
    logic pop1;
    logic push0;
    logic push1;

    logic [1:0] pop_count;
    logic [1:0] push_count;

    logic [PTR_BITS-1:0] read_ptr_next;
    logic [PTR_BITS-1:0] write_ptr_next;

    integer occupancy_after_pop;
    integer free_slots_after_pop;

    function automatic logic [PTR_BITS-1:0] advance_ptr(
        input logic [PTR_BITS-1:0] ptr,
        input integer amount
    );
        integer next_value;
        begin
            next_value = (int'(ptr) + amount) % QUEUE_DEPTH;
            advance_ptr = PTR_BITS'(next_value);
        end
    endfunction

    always_comb begin
        out_valid0 = (queue_count >= 1);
        out_valid1 = (queue_count >= 2);

        out_pc0 = '0;
        out_instruction0 = '0;
        out_predicted_taken0 = 1'b0;
        out_predicted_target0 = '0;
        out_history_snapshot0 = '0;

        out_pc1 = '0;
        out_instruction1 = '0;
        out_predicted_taken1 = 1'b0;
        out_predicted_target1 = '0;
        out_history_snapshot1 = '0;

        if (out_valid0) begin
            out_pc0 = pc_mem[read_ptr];
            out_instruction0 = instruction_mem[read_ptr];
            out_predicted_taken0 = predicted_taken_mem[read_ptr];
            out_predicted_target0 = predicted_target_mem[read_ptr];
            out_history_snapshot0 = history_snapshot_mem[read_ptr];
        end

        if (out_valid1) begin
            out_pc1 = pc_mem[advance_ptr(read_ptr, 1)];
            out_instruction1 = instruction_mem[advance_ptr(read_ptr, 1)];
            out_predicted_taken1 = predicted_taken_mem[advance_ptr(read_ptr, 1)];
            out_predicted_target1 = predicted_target_mem[advance_ptr(read_ptr, 1)];
            out_history_snapshot1 = history_snapshot_mem[advance_ptr(read_ptr, 1)];
        end
    end

    always_comb begin
        pop0 = out_valid0 && out_ready0;
        pop1 = pop0 && out_valid1 && out_ready1;

        pop_count = {1'b0, pop0} + {1'b0, pop1};

        occupancy_after_pop =
            int'(queue_count) - int'(pop_count);

        free_slots_after_pop =
            QUEUE_DEPTH - occupancy_after_pop;

        in_ready0 = 1'b0;
        in_ready1 = 1'b0;

        if (!flush) begin
            in_ready0 = (free_slots_after_pop >= 1);
            in_ready1 =
                in_valid0 &&
                (free_slots_after_pop >= 2);
        end

        push0 = in_valid0 && in_ready0;
        push1 = in_valid1 && in_ready1;

        push_count = {1'b0, push0} + {1'b0, push1};
    end

    always_comb begin
        read_ptr_next = advance_ptr(read_ptr, int'(pop_count));
        write_ptr_next = advance_ptr(write_ptr, int'(push_count));
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= '0;
            write_ptr <= '0;
            queue_count <= '0;
        end else if (flush) begin
            read_ptr <= '0;
            write_ptr <= '0;
            queue_count <= '0;
        end else begin
            if (push0) begin
                pc_mem[write_ptr] <= in_pc0;
                instruction_mem[write_ptr] <= in_instruction0;
                predicted_taken_mem[write_ptr] <= in_predicted_taken0;
                predicted_target_mem[write_ptr] <= in_predicted_target0;
                history_snapshot_mem[write_ptr] <= in_history_snapshot0;
            end

            if (push1) begin
                pc_mem[advance_ptr(write_ptr, 1)] <= in_pc1;
                instruction_mem[advance_ptr(write_ptr, 1)] <= in_instruction1;
                predicted_taken_mem[advance_ptr(write_ptr, 1)] <= in_predicted_taken1;
                predicted_target_mem[advance_ptr(write_ptr, 1)] <= in_predicted_target1;
                history_snapshot_mem[advance_ptr(write_ptr, 1)] <= in_history_snapshot1;
            end

            read_ptr <= read_ptr_next;
            write_ptr <= write_ptr_next;

            queue_count <= COUNT_BITS'(
                occupancy_after_pop + int'(push_count)
            );
        end
    end

endmodule
