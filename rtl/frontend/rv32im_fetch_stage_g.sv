
module rv32im_fetch_stage_g #(
    parameter int PC_BITS = 32,
    parameter int INST_BITS = 32
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic redirect_valid,
    input logic [PC_BITS-1:0] redirect_pc,

    output logic fetch_req_valid,
    input logic fetch_req_ready,
    output logic [PC_BITS-1:0] fetch_req_addr,

    input logic fetch_resp_valid,
    output logic fetch_resp_ready,
    input logic [63:0] fetch_resp_data,

    output logic fetch_valid0,
    input logic fetch_ready0,
    output logic [PC_BITS-1:0] fetch_pc0,
    output logic [INST_BITS-1:0] fetch_inst0,

    output logic fetch_valid1,
    input logic fetch_ready1,
    output logic [PC_BITS-1:0] fetch_pc1,
    output logic [INST_BITS-1:0] fetch_inst1
);

    logic [PC_BITS-1:0] pc;
    logic [PC_BITS-1:0] request_pc;
    logic request_pending;
    logic response_pending;
    logic [63:0] response_data;
    logic [PC_BITS-1:0] response_pc;
    logic response_valid;
    logic [PC_BITS-1:0] next_pc;
    logic consume_response;

    always_comb begin
        consume_response = response_valid &&
                           fetch_ready0 &&
                           fetch_ready1;

        next_pc = response_pc + PC_BITS'(8);

        // the next request may be issued in the same cycle the current packet is consumed
        fetch_req_valid = !request_pending &&
                          !response_pending &&
                          (!response_valid || consume_response) &&
                          !flush &&
                          !redirect_valid;

        if (consume_response)
            fetch_req_addr = {next_pc[PC_BITS-1:3], 3'b000};
        else
            fetch_req_addr = {pc[PC_BITS-1:3], 3'b000};

        fetch_resp_ready = request_pending &&
                           !response_pending &&
                           !flush &&
                           !redirect_valid;

        fetch_valid0 = response_valid;
        fetch_valid1 = response_valid;

        fetch_pc0 = response_pc;
        fetch_pc1 = response_pc + PC_BITS'(4);

        fetch_inst0 = response_data[31:0];
        fetch_inst1 = response_data[63:32];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= '0;
            request_pc <= '0;
            request_pending <= 1'b0;
            response_pending <= 1'b0;
            response_data <= '0;
            response_pc <= '0;
            response_valid <= 1'b0;
        end else if (flush || redirect_valid) begin
            pc <= redirect_valid ? redirect_pc : pc;
            request_pc <= '0;
            request_pending <= 1'b0;
            response_pending <= 1'b0;
            response_valid <= 1'b0;
        end else begin
            if (fetch_req_valid && fetch_req_ready) begin
                request_pc <= fetch_req_addr;
                request_pending <= 1'b1;
            end

            if (fetch_resp_valid && fetch_resp_ready) begin
                response_data <= fetch_resp_data;
                response_pc <= request_pc;
                response_pending <= 1'b0;
                request_pending <= 1'b0;
                response_valid <= 1'b1;
            end

            if (consume_response) begin
                response_valid <= 1'b0;
                pc <= next_pc;
            end
        end
    end

endmodule
