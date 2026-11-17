
module rv32im_exec_arbiter_g #(
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32,
    parameter int ROB_BITS  = 5
) (
    input  logic                  in_valid0,
    input  logic [PHYS_BITS-1:0]  in_pdst0,
    input  logic [DATA_BITS-1:0]  in_data0,
    input  logic [ROB_BITS-1:0]   in_rob_idx0,

    input  logic                  in_valid1,
    input  logic [PHYS_BITS-1:0]  in_pdst1,
    input  logic [DATA_BITS-1:0]  in_data1,
    input  logic [ROB_BITS-1:0]   in_rob_idx1,

    output logic                  in_ready0,
    output logic                  in_ready1,

    output logic                  out_valid,
    output logic [PHYS_BITS-1:0]  out_pdst,
    output logic [DATA_BITS-1:0]  out_data,
    output logic [ROB_BITS-1:0]   out_rob_idx,

    input  logic                  out_ready
);

    always_comb begin
        in_ready0 = 1'b0;
        in_ready1 = 1'b0;

        out_valid = 1'b0;
        out_pdst  = '0;
        out_data  = '0;
        out_rob_idx = '0;

        if (in_valid0) begin
            out_valid = 1'b1;
            out_pdst = in_pdst0;
            out_data = in_data0;
            out_rob_idx = in_rob_idx0;

            in_ready0 = out_ready;
        end
        else if (in_valid1) begin
            out_valid = 1'b1;
            out_pdst = in_pdst1;
            out_data = in_data1;
            out_rob_idx = in_rob_idx1;

            in_ready1 = out_ready;
        end
    end

endmodule
