module rv32im_uop_tbl_g #(
    parameter int UW = 251
) (
    input  logic clk,
    input  logic rst_n,

    input  logic          wr_valid0,
    input  logic [4:0]    wr_idx0,
    input  logic [UW-1:0] wr_data0,
    input  logic          wr_valid1,
    input  logic [4:0]    wr_idx1,
    input  logic [UW-1:0] wr_data1,

    input  logic [4:0]    rd_ex_idx0,
    output logic [UW-1:0] rd_ex_data0,
    input  logic [4:0]    rd_ex_idx1,
    output logic [UW-1:0] rd_ex_data1,

    input  logic [4:0]    rd_cm_idx0,
    output logic [UW-1:0] rd_cm_data0,
    input  logic [4:0]    rd_cm_idx1,
    output logic [UW-1:0] rd_cm_data1,

    input  logic [4:0]    rd_ld_idx,
    output logic [UW-1:0] rd_ld_data,

    output logic [31:0] is_load_vec,
    output logic [31:0] is_store_vec
);

    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] pred_pc;
        logic [31:0] imm;
        logic [31:0] instr;
        logic [31:0] src1_data;
        logic [31:0] src2_data;
        logic [4:0] rd;
        logic [5:0] pdst;
        logic [5:0] old_pdst;
        logic [5:0] psrc1;
        logic [5:0] psrc2;
        logic [4:0] alu_op;
        logic [2:0] funct3;
        logic [3:0] ghist;
        logic [1:0] msize;
        logic src1_ready;
        logic src2_ready;
        logic writes_rd;
        logic uses_rs2;
        logic is_auipc;
        logic is_branch;
        logic is_jal;
        logic is_jalr;
        logic is_load;
        logic is_store;
        logic is_muldiv;
        logic is_system;
        logic is_fence;
        logic illegal;
        logic load_unsigned;
        logic pred_taken;
    } uop_t;

    uop_t tbl [0:31];

    integer ti;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ti = 0; ti < 32; ti = ti + 1)
                tbl[ti] <= '0;
        end
        else begin
            if (wr_valid0)
                tbl[wr_idx0] <= wr_data0;

            if (wr_valid1)
                tbl[wr_idx1] <= wr_data1;
        end
    end

    always_comb begin
        rd_ex_data0 = tbl[rd_ex_idx0];
        rd_ex_data1 = tbl[rd_ex_idx1];
        rd_cm_data0 = tbl[rd_cm_idx0];
        rd_cm_data1 = tbl[rd_cm_idx1];
        rd_ld_data  = tbl[rd_ld_idx];

        for (int k = 0; k < 32; k = k + 1) begin
            is_load_vec[k]  = tbl[k].is_load;
            is_store_vec[k] = tbl[k].is_store;
        end
    end

endmodule