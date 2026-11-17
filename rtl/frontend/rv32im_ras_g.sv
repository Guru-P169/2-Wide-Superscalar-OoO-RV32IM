module rv32im_ras_g #(
    parameter int RAS_DEPTH = 8,
    parameter int RAS_PTR_BITS = (RAS_DEPTH > 1) ? $clog2(RAS_DEPTH) : 1,
    parameter int RAS_COUNT_BITS = $clog2(RAS_DEPTH + 1)
) (
    input logic clk,
    input logic rst_n,

    input logic push_valid,
    input logic [31:0] push_addr,

    input logic pop_valid,

    input logic checkpoint_save,
    output logic [RAS_PTR_BITS-1:0] checkpoint_ptr,
    output logic [RAS_COUNT_BITS-1:0] checkpoint_count,
    output logic [RAS_DEPTH*32-1:0] checkpoint_stack,

    input logic checkpoint_restore,
    input logic [RAS_PTR_BITS-1:0] restore_ptr,
    input logic [RAS_COUNT_BITS-1:0] restore_count,
    input logic [RAS_DEPTH*32-1:0] restore_stack,

    output logic ras_valid,
    output logic [31:0] ras_target,
    output logic [RAS_PTR_BITS-1:0] cur_ptr,
    output logic [RAS_COUNT_BITS-1:0] cur_count,
    output logic [RAS_DEPTH*32-1:0] cur_stack
);

    logic [31:0] stack [0:RAS_DEPTH-1];

    logic [RAS_PTR_BITS-1:0] stack_ptr;
    logic [RAS_COUNT_BITS-1:0] stack_count;
    logic [RAS_PTR_BITS-1:0] previous_ptr;

    integer i;

    always_comb begin
        cur_ptr = stack_ptr;
        cur_count = stack_count;
        for (int k = 0; k < RAS_DEPTH; k = k + 1)
            cur_stack[k*32 +: 32] = stack[k];
    end

    always_comb begin
        if (stack_ptr == 0)
            previous_ptr = RAS_PTR_BITS'(RAS_DEPTH - 1);
        else
            previous_ptr = stack_ptr - 1'b1;

        ras_valid = (stack_count != 0);
        ras_target = '0;

        if (ras_valid)
            ras_target = stack[previous_ptr];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stack_ptr <= '0;
            stack_count <= '0;

            checkpoint_ptr <= '0;
            checkpoint_count <= '0;
            checkpoint_stack <= '0;

            for (i = 0; i < RAS_DEPTH; i = i + 1)
                stack[i] <= '0;

        end else if (checkpoint_restore) begin
            if ((restore_ptr < RAS_DEPTH) &&
                (restore_count <= RAS_DEPTH)) begin

                stack_ptr <= restore_ptr;
                stack_count <= restore_count;

                for (i = 0; i < RAS_DEPTH; i = i + 1)
                    stack[i] <= restore_stack[i*32 +: 32];
            end

        end else begin
            if (checkpoint_save) begin
                checkpoint_ptr <= stack_ptr;
                checkpoint_count <= stack_count;

                for (i = 0; i < RAS_DEPTH; i = i + 1)
                    checkpoint_stack[i*32 +: 32] <= stack[i];
            end

            case ({push_valid, pop_valid})

                2'b10: begin
                    stack[stack_ptr] <= push_addr;

                    if (stack_ptr == RAS_DEPTH - 1)
                        stack_ptr <= '0;
                    else
                        stack_ptr <= stack_ptr + 1'b1;

                    if (stack_count < RAS_DEPTH)
                        stack_count <= stack_count + 1'b1;
                end

                2'b01: begin
                    if (stack_count != 0) begin
                        stack_ptr <= previous_ptr;
                        stack_count <= stack_count - 1'b1;
                    end
                end

                2'b11: begin
                    if (stack_count == 0) begin
                        stack[stack_ptr] <= push_addr;

                        if (stack_ptr == RAS_DEPTH - 1)
                            stack_ptr <= '0;
                        else
                            stack_ptr <= stack_ptr + 1'b1;

                        stack_count <= RAS_COUNT_BITS'(1);
                    end else begin
                        stack[previous_ptr] <= push_addr;
                    end
                end

                default: begin
                    stack_ptr <= stack_ptr;
                    stack_count <= stack_count;
                end

            endcase
        end
    end

endmodule