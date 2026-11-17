
module rv32im_gshare_bht_g #(
    parameter int GHR_BITS = 4,
    parameter int PHT_ENTRIES = 16
) (
    input logic clk,
    input logic rst_n,

    input logic [31:0] predict_pc0,
    input logic [GHR_BITS-1:0] predict_history0,
    output logic predict_taken0,

    input logic [31:0] predict_pc1,
    input logic [GHR_BITS-1:0] predict_history1,
    output logic predict_taken1,

    input logic update_valid,
    input logic [31:0] update_pc,
    input logic [GHR_BITS-1:0] update_history,
    input logic actual_taken
);

    localparam int PHT_INDEX_BITS =
        (PHT_ENTRIES > 1) ? $clog2(PHT_ENTRIES) : 1;

    logic [1:0] pht [0:PHT_ENTRIES-1];

    integer predict_index0;
    integer predict_index1;
    integer update_index;

    integer i;

    function automatic integer calculate_index(
        input logic [31:0] pc,
        input logic [GHR_BITS-1:0] history
    );
        logic [PHT_INDEX_BITS-1:0] pc_index;
        logic [PHT_INDEX_BITS-1:0] history_index;

        begin
            pc_index = pc >> 2;
            history_index = history;

            calculate_index =
                (pc_index ^ history_index) % PHT_ENTRIES;
        end
    endfunction

    always_comb begin
        predict_index0 =
            calculate_index(predict_pc0, predict_history0);

        predict_index1 =
            calculate_index(predict_pc1, predict_history1);

        update_index =
            calculate_index(update_pc, update_history);

        predict_taken0 = pht[predict_index0][1];
        predict_taken1 = pht[predict_index1][1];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < PHT_ENTRIES; i = i + 1)
                pht[i] <= 2'b01;
        end else if (update_valid) begin
            if (actual_taken) begin
                if (pht[update_index] != 2'b11)
                    pht[update_index] <= pht[update_index] + 2'b01;
            end else begin
                if (pht[update_index] != 2'b00)
                    pht[update_index] <= pht[update_index] - 2'b01;
            end
        end
    end

endmodule
