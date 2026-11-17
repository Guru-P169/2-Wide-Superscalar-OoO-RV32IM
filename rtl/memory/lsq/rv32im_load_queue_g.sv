
module rv32im_load_queue_g #(
    parameter int DEPTH = 16,
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int TAG_BITS = 6,
    parameter int PTR_BITS = $clog2(DEPTH)
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic alloc_valid,
    output logic alloc_ready,
    input logic [TAG_BITS-1:0] alloc_rob_tag,

    input logic update_valid,
    input logic [TAG_BITS-1:0] update_rob_tag,
    input logic [ADDR_BITS-1:0] update_addr,
    input logic [DATA_BITS-1:0] update_data,
    input logic update_addr_valid,
    input logic update_data_valid,

    input logic retire_valid,
    input logic [TAG_BITS-1:0] retire_rob_tag,

    output logic head_valid,
    output logic [TAG_BITS-1:0] head_rob_tag,
    output logic [ADDR_BITS-1:0] head_addr,
    output logic [DATA_BITS-1:0] head_data,
    output logic head_addr_valid,
    output logic head_data_valid,

    output logic full,
    output logic empty,
    output logic [$clog2(DEPTH+1)-1:0] count
);

    localparam int COUNT_BITS = $clog2(DEPTH + 1);

    logic [TAG_BITS-1:0] rob_tag_array [0:DEPTH-1];
    logic [ADDR_BITS-1:0] addr_array [0:DEPTH-1];
    logic [DATA_BITS-1:0] data_array [0:DEPTH-1];
    logic addr_valid_array [0:DEPTH-1];
    logic data_valid_array [0:DEPTH-1];
    logic entry_valid_array [0:DEPTH-1];

    logic [PTR_BITS-1:0] read_ptr;
    logic [PTR_BITS-1:0] write_ptr;

    integer i;

    always_comb begin
        empty = (count == 0);
        full = (count == DEPTH);
        alloc_ready = !full;

        head_valid = !empty && entry_valid_array[read_ptr];
        head_rob_tag = rob_tag_array[read_ptr];
        head_addr = addr_array[read_ptr];
        head_data = data_array[read_ptr];
        head_addr_valid = addr_valid_array[read_ptr];
        head_data_valid = data_valid_array[read_ptr];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= '0;
            write_ptr <= '0;
            count <= '0;

            for (i = 0; i < DEPTH; i++) begin
                rob_tag_array[i] <= '0;
                addr_array[i] <= '0;
                data_array[i] <= '0;
                addr_valid_array[i] <= 1'b0;
                data_valid_array[i] <= 1'b0;
                entry_valid_array[i] <= 1'b0;
            end
        end else if (flush) begin
            read_ptr <= '0;
            write_ptr <= '0;
            count <= '0;

            for (i = 0; i < DEPTH; i++) begin
                addr_valid_array[i] <= 1'b0;
                data_valid_array[i] <= 1'b0;
                entry_valid_array[i] <= 1'b0;
            end
        end else begin
            if (alloc_valid && alloc_ready) begin
                rob_tag_array[write_ptr] <= alloc_rob_tag;
                addr_array[write_ptr] <= '0;
                data_array[write_ptr] <= '0;
                addr_valid_array[write_ptr] <= 1'b0;
                data_valid_array[write_ptr] <= 1'b0;
                entry_valid_array[write_ptr] <= 1'b1;

                if (write_ptr == DEPTH - 1) begin
                    write_ptr <= '0;
                end else begin
                    write_ptr <= write_ptr + 1'b1;
                end
            end

            if (update_valid) begin
                for (i = 0; i < DEPTH; i++) begin
                    if (entry_valid_array[i] &&
                        rob_tag_array[i] == update_rob_tag) begin
                        if (update_addr_valid) begin
                            addr_array[i] <= update_addr;
                            addr_valid_array[i] <= 1'b1;
                        end

                        if (update_data_valid) begin
                            data_array[i] <= update_data;
                            data_valid_array[i] <= 1'b1;
                        end
                    end
                end
            end

            if (retire_valid && !empty &&
                rob_tag_array[read_ptr] == retire_rob_tag) begin
                entry_valid_array[read_ptr] <= 1'b0;
                addr_valid_array[read_ptr] <= 1'b0;
                data_valid_array[read_ptr] <= 1'b0;

                if (read_ptr == DEPTH - 1) begin
                    read_ptr <= '0;
                end else begin
                    read_ptr <= read_ptr + 1'b1;
                end
            end

            case ({
                alloc_valid && alloc_ready,
                retire_valid && !empty &&
                rob_tag_array[read_ptr] == retire_rob_tag
            })
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
