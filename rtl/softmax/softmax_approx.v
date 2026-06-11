`timescale 1ns/1ps

// Row-wise softmax approximation for one 8-element score row.
//
// Fixed-point formats:
//   score_row: signed int32 scores from Q*K^T or a later scaled score stage.
//   exp_row:   unsigned Q8.8 approximate exp(score - max), internal only.
//   prob_row:  unsigned Q0.8 probabilities, one byte per row element.
//
// This is a simple approximation intended for simulation bring-up. It does not
// claim exact floating-point softmax behavior.
module softmax_approx #(
    parameter ROW_LEN = 8,
    parameter SCORE_W = 32,
    parameter EXP_W   = 16,
    parameter SUM_W   = 20,
    parameter PROB_W  = 8
)(
    input  wire signed [(ROW_LEN*SCORE_W)-1:0] score_row,
    output reg  [(ROW_LEN*PROB_W)-1:0]         prob_row,
    output wire signed [SCORE_W-1:0]           max_value,
    output wire [SUM_W-1:0]                    exp_sum
);

    wire [(ROW_LEN*EXP_W)-1:0] exp_row;

    genvar gi;
    generate
        for (gi = 0; gi < ROW_LEN; gi = gi + 1) begin : gen_exp_lut
            wire signed [SCORE_W-1:0] score_elem;
            wire signed [SCORE_W-1:0] diff;

            assign score_elem = score_row[(gi*SCORE_W) +: SCORE_W];
            assign diff = score_elem - max_value;

            exp_lut #(
                .DIFF_W(SCORE_W),
                .EXP_W(EXP_W)
            ) exp_lut_i (
                .diff(diff),
                .exp_value(exp_row[(gi*EXP_W) +: EXP_W])
            );
        end
    endgenerate

    row_max #(
        .ROW_LEN(ROW_LEN),
        .SCORE_W(SCORE_W)
    ) row_max_i (
        .score_row(score_row),
        .max_value(max_value)
    );

    row_sum #(
        .ROW_LEN(ROW_LEN),
        .EXP_W(EXP_W),
        .SUM_W(SUM_W)
    ) row_sum_i (
        .exp_row(exp_row),
        .sum_value(exp_sum)
    );

    integer i;
    reg [EXP_W-1:0] exp_elem;
    reg [(EXP_W+PROB_W)-1:0] scaled_exp;

    always @* begin
        prob_row = {(ROW_LEN*PROB_W){1'b0}};
        for (i = 0; i < ROW_LEN; i = i + 1) begin
            exp_elem = exp_row[(i*EXP_W) +: EXP_W];
            scaled_exp = exp_elem * {PROB_W{1'b1}};
            if (exp_sum != {SUM_W{1'b0}}) begin
                prob_row[(i*PROB_W) +: PROB_W] = scaled_exp / exp_sum;
            end else begin
                prob_row[(i*PROB_W) +: PROB_W] = {PROB_W{1'b0}};
            end
        end
    end

endmodule
