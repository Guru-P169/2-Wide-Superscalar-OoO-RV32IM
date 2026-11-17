
module rv32im_wakeup_select_g #(
    parameter int PHYS_BITS = 6,
    parameter int DATA_BITS = 32,
    parameter int INPUTS = 4,
    parameter int OUTPUTS = 2,
    parameter int INDEX_BITS = (INPUTS > 1) ? $clog2(INPUTS) : 1
) (
    input logic [INPUTS-1:0] in_valid,
    input logic [INPUTS*PHYS_BITS-1:0] in_pdst,
    input logic [INPUTS*DATA_BITS-1:0] in_data,

    output logic [OUTPUTS-1:0] out_valid,
    output logic [OUTPUTS*PHYS_BITS-1:0] out_pdst,
    output logic [OUTPUTS*DATA_BITS-1:0] out_data,
    output logic [OUTPUTS*INDEX_BITS-1:0] out_index
);

    logic [INPUTS-1:0] selected;
    integer output_slot;

    always_comb begin
        selected = '0;
        out_valid = '0;
        out_pdst = '0;
        out_data = '0;
        out_index = '0;
        output_slot = 0;

        for (int i = 0; i < INPUTS; i = i + 1) begin
            if (in_valid[i] && output_slot < OUTPUTS) begin
                selected[i] = 1'b1;
                out_valid[output_slot] = 1'b1;
                out_pdst[output_slot*PHYS_BITS +: PHYS_BITS] =
                    in_pdst[i*PHYS_BITS +: PHYS_BITS];
                out_data[output_slot*DATA_BITS +: DATA_BITS] =
                    in_data[i*DATA_BITS +: DATA_BITS];
                out_index[output_slot*INDEX_BITS +: INDEX_BITS] = INDEX_BITS'(i);
                output_slot = output_slot + 1;
            end
        end
    end

endmodule
