
module rv32im_lsq_g #(
    parameter int DEPTH = 16,
    parameter int ADDR_BITS = 32,
    parameter int DATA_BITS = 32,
    parameter int TAG_BITS = 6,
    parameter int COUNT_BITS = $clog2(DEPTH + 1)
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic load_alloc_valid,
    output logic load_alloc_ready,
    input logic [TAG_BITS-1:0] load_alloc_rob_tag,

    input logic store_alloc_valid,
    output logic store_alloc_ready,
    input logic [TAG_BITS-1:0] store_alloc_rob_tag,

    input logic load_retire_valid,
    input logic [TAG_BITS-1:0] load_retire_rob_tag,

    input logic store_retire_valid,
    input logic [TAG_BITS-1:0] store_retire_rob_tag,

    input logic load_update_valid,
    input logic [TAG_BITS-1:0] load_update_rob_tag,
    input logic [ADDR_BITS-1:0] load_update_addr,
    input logic [DATA_BITS-1:0] load_update_data,
    input logic load_update_addr_valid,
    input logic load_update_data_valid,

    input logic store_update_valid,
    input logic [TAG_BITS-1:0] store_update_rob_tag,
    input logic [ADDR_BITS-1:0] store_update_addr,
    input logic [DATA_BITS-1:0] store_update_data,
    input logic [3:0] store_update_wstrb,
    input logic store_update_addr_valid,
    input logic store_update_data_valid,

    output logic load_head_valid,
    output logic [TAG_BITS-1:0] load_head_rob_tag,
    output logic [ADDR_BITS-1:0] load_head_addr,
    output logic [DATA_BITS-1:0] load_head_data,
    output logic load_head_addr_valid,
    output logic load_head_data_valid,

    output logic store_head_valid,
    output logic [TAG_BITS-1:0] store_head_rob_tag,
    output logic [ADDR_BITS-1:0] store_head_addr,
    output logic [DATA_BITS-1:0] store_head_data,
    output logic [3:0] store_head_wstrb,
    output logic store_head_addr_valid,
    output logic store_head_data_valid,

    output logic load_full,
    output logic load_empty,
    output logic [COUNT_BITS-1:0] load_count,

    output logic store_full,
    output logic store_empty,
    output logic [COUNT_BITS-1:0] store_count
);

    rv32im_load_queue_g #(
        .DEPTH(DEPTH),
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .TAG_BITS(TAG_BITS)
    ) load_queue (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),

        .alloc_valid(load_alloc_valid),
        .alloc_ready(load_alloc_ready),
        .alloc_rob_tag(load_alloc_rob_tag),

        .update_valid(load_update_valid),
        .update_rob_tag(load_update_rob_tag),
        .update_addr(load_update_addr),
        .update_data(load_update_data),
        .update_addr_valid(load_update_addr_valid),
        .update_data_valid(load_update_data_valid),

        .retire_valid(load_retire_valid),
        .retire_rob_tag(load_retire_rob_tag),

        .head_valid(load_head_valid),
        .head_rob_tag(load_head_rob_tag),
        .head_addr(load_head_addr),
        .head_data(load_head_data),
        .head_addr_valid(load_head_addr_valid),
        .head_data_valid(load_head_data_valid),

        .full(load_full),
        .empty(load_empty),
        .count(load_count)
    );

    rv32im_store_queue_g #(
        .DEPTH(DEPTH),
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .TAG_BITS(TAG_BITS)
    ) store_queue (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),

        .alloc_valid(store_alloc_valid),
        .alloc_ready(store_alloc_ready),
        .alloc_rob_tag(store_alloc_rob_tag),

        .update_valid(store_update_valid),
        .update_rob_tag(store_update_rob_tag),
        .update_addr(store_update_addr),
        .update_data(store_update_data),
        .update_wstrb(store_update_wstrb),
        .update_addr_valid(store_update_addr_valid),
        .update_data_valid(store_update_data_valid),

        .retire_valid(store_retire_valid),
        .retire_rob_tag(store_retire_rob_tag),

        .head_valid(store_head_valid),
        .head_rob_tag(store_head_rob_tag),
        .head_addr(store_head_addr),
        .head_data(store_head_data),
        .head_wstrb(store_head_wstrb),
        .head_addr_valid(store_head_addr_valid),
        .head_data_valid(store_head_data_valid),

        .full(store_full),
        .empty(store_empty),
        .count(store_count)
    );

endmodule
