module rv32im_muldiv_unit_g (
    input  logic clk,
    input  logic rst_n,

    input  logic req_valid,
    output logic req_ready,
    input  logic [2:0]  req_funct3,
    input  logic [31:0] req_operand_a,
    input  logic [31:0] req_operand_b,

    output logic rsp_valid,
    input  logic rsp_ready,
    output logic [31:0] rsp_result
);

    localparam logic [2:0] M_MUL = 3'b000;
    localparam logic [2:0] M_MULH = 3'b001;
    localparam logic [2:0] M_MULHSU = 3'b010;
    localparam logic [2:0] M_MULHU  = 3'b011;
    localparam logic [2:0] M_DIV    = 3'b100;
    localparam logic [2:0] M_DIVU   = 3'b101;
    localparam logic [2:0] M_REM    = 3'b110;
    localparam logic [2:0] M_REMU   = 3'b111;

    localparam logic [2:0] S_IDLE = 3'd0;
    localparam logic [2:0] S_MUL1 = 3'd1;
    localparam logic [2:0] S_MUL2 = 3'd2;
    localparam logic [2:0] S_DPRE = 3'd3;
    localparam logic [2:0] S_DRUN = 3'd4;
    localparam logic [2:0] S_DFIN = 3'd5;

    logic [2:0] state;

    logic [2:0]  f3_r;
    logic [31:0] a_r;
    logic [31:0] b_r;

    logic signed [33:0] pp_ll;
    logic signed [33:0] pp_lh;
    logic signed [33:0] pp_hl;
    logic signed [33:0] pp_hh;

    logic [31:0] rem_r;
    logic [31:0] quo_r;
    logic [31:0] den_r;
    logic [5:0]  cnt_r;
    logic        q_neg_r;
    logic        r_neg_r;

    logic flush_i;
    logic accept;

    logic signed [32:0] mul_a;
    logic signed [32:0] mul_b;
    logic signed [16:0] a_hi;
    logic signed [16:0] a_lo;
    logic signed [16:0] b_hi;
    logic signed [16:0] b_lo;
    logic signed [33:0] pp_ll_n;
    logic signed [33:0] pp_lh_n;
    logic signed [33:0] pp_hl_n;
    logic signed [33:0] pp_hh_n;

    logic signed [34:0] mid_sum;
    logic signed [65:0] prod;
    logic [31:0]        mul_out;

    logic        div_signed;
    logic        a_neg;
    logic        b_neg;
    logic        b_is_zero;
    logic [31:0] abs_a;
    logic [31:0] abs_b;

    logic [32:0] rem_sh;
    logic [32:0] rem_diff;
    logic        sub_ge;

    logic [31:0] quo_fix;
    logic [31:0] rem_fix;
    logic [31:0] div_out;

    assign flush_i = rsp_ready && !rsp_valid;

    assign req_ready = (state == S_IDLE) && (!rsp_valid || rsp_ready);
    assign accept    = req_valid && req_ready && !flush_i;

    always_comb begin
        mul_a = {(((f3_r == M_MULH) || (f3_r == M_MULHSU)) & a_r[31]), a_r};
        mul_b = {((f3_r == M_MULH) & b_r[31]), b_r};

        a_hi = mul_a[32:16];
        a_lo = {1'b0, mul_a[15:0]};
        b_hi = mul_b[32:16];
        b_lo = {1'b0, mul_b[15:0]};

        pp_ll_n = a_lo * b_lo;
        pp_lh_n = a_lo * b_hi;
        pp_hl_n = a_hi * b_lo;
        pp_hh_n = a_hi * b_hi;

        mid_sum = pp_lh + pp_hl;

        prod = ({{32{pp_hh[33]}}, pp_hh} << 32) +
               ({{31{mid_sum[34]}}, mid_sum} << 16) +
               {{32{pp_ll[33]}}, pp_ll};

        mul_out = (f3_r == M_MUL) ? prod[31:0] : prod[63:32];
    end

    always_comb begin
        div_signed = ~f3_r[0];
        a_neg      = div_signed & a_r[31];
        b_neg      = div_signed & b_r[31];
        b_is_zero  = (b_r == 32'b0);

        abs_a = a_neg ? (~a_r + 32'd1) : a_r;
        abs_b = b_neg ? (~b_r + 32'd1) : b_r;

        rem_sh   = {rem_r, quo_r[31]};
        rem_diff = rem_sh - {1'b0, den_r};
        sub_ge   = !rem_diff[32];

        quo_fix = q_neg_r ? (~quo_r + 32'd1) : quo_r;
        rem_fix = r_neg_r ? (~rem_r + 32'd1) : rem_r;
        div_out = f3_r[1] ? rem_fix : quo_fix;
    end

    always_ff @(posedge clk) begin
        if (accept) begin
            f3_r <= req_funct3;
            a_r  <= req_operand_a;
            b_r  <= req_operand_b;
        end

        if (state == S_MUL1) begin
            pp_ll <= pp_ll_n;
            pp_lh <= pp_lh_n;
            pp_hl <= pp_hl_n;
            pp_hh <= pp_hh_n;
        end

        if (state == S_DPRE) begin
            rem_r   <= 32'b0;
            quo_r   <= abs_a;
            den_r   <= abs_b;
            cnt_r   <= 6'd0;
            q_neg_r <= a_neg ^ b_neg;
            r_neg_r <= a_neg;
        end
        else if (state == S_DRUN) begin
            rem_r <= sub_ge ? rem_diff[31:0] : rem_sh[31:0];
            quo_r <= {quo_r[30:0], sub_ge};
            cnt_r <= cnt_r + 6'd1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            rsp_valid  <= 1'b0;
            rsp_result <= 32'b0;
        end
        else if (flush_i) begin
            state     <= S_IDLE;
            rsp_valid <= 1'b0;
        end
        else begin
            if (rsp_valid && rsp_ready)
                rsp_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (accept)
                        state <= req_funct3[2] ? S_DPRE : S_MUL1;
                end

                S_MUL1: begin
                    state <= S_MUL2;
                end

                S_MUL2: begin
                    rsp_result <= mul_out;
                    rsp_valid  <= 1'b1;
                    state      <= S_IDLE;
                end

                S_DPRE: begin
                    if (b_is_zero) begin
                        rsp_result <= f3_r[1] ? a_r : 32'hFFFF_FFFF;
                        rsp_valid  <= 1'b1;
                        state      <= S_IDLE;
                    end
                    else begin
                        state <= S_DRUN;
                    end
                end

                S_DRUN: begin
                    if (cnt_r == 6'd31)
                        state <= S_DFIN;
                end

                S_DFIN: begin
                    rsp_result <= div_out;
                    rsp_valid  <= 1'b1;
                    state      <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule