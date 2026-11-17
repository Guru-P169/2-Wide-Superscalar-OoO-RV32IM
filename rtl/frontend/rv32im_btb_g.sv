
module rv32im_btb_g #(
    parameter int BTB_ENTRIES = 16
) (
    input logic clk,
    input logic rst_n,

    input logic [31:0] predict_pc0,
    output logic predict_hit0,
    output logic [31:0] predict_target0,

    input logic [31:0] predict_pc1,
    output logic predict_hit1,
    output logic [31:0] predict_target1,

    input logic update_valid,
    input logic [31:0] update_pc,
    input logic [31:0] update_target
);

    logic [BTB_ENTRIES-1:0] valid_bits;

    logic [29:0] tags [0:BTB_ENTRIES-1];
    logic [31:0] targets [0:BTB_ENTRIES-1];

    integer predict_index0;
    integer predict_index1;
    integer update_index;

    function automatic integer calculate_index(
        input logic [31:0] pc
    );
        begin
            calculate_index = (pc >> 2) % BTB_ENTRIES;
        end
    endfunction

    always_comb begin
        predict_index0 = calculate_index(predict_pc0);
        predict_index1 = calculate_index(predict_pc1);
        update_index = calculate_index(update_pc);

        predict_hit0 = 1'b0;
        predict_target0 = '0;

        if (valid_bits[predict_index0] &&
            tags[predict_index0] == predict_pc0[31:2]) begin
            predict_hit0 = 1'b1;
            predict_target0 = targets[predict_index0];
        end

        predict_hit1 = 1'b0;
        predict_target1 = '0;

        if (valid_bits[predict_index1] &&
            tags[predict_index1] == predict_pc1[31:2]) begin
            predict_hit1 = 1'b1;
            predict_target1 = targets[predict_index1];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_bits <= '0;

            for (integer i = 0; i < BTB_ENTRIES; i = i + 1) begin
                tags[i] <= '0;
                targets[i] <= '0;
            end
        end else if (update_valid) begin
            valid_bits[update_index] <= 1'b1;
            tags[update_index] <= update_pc[31:2];
            targets[update_index] <= update_target;
        end
    end

endmodule
