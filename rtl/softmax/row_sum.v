`timescale 1ns/1ps

// Combinational sum for an 8-element row of unsigned fixed-point exp values.
module row_sum #(
    parameter ROW_LEN = 8,
    parameter EXP_W   = 16,
    parameter SUM_W   = 20
)(
    input  wire [(ROW_LEN*EXP_W)-1:0] exp_row,
    output reg  [SUM_W-1:0]           sum_value
);

    integer i;

    always @* begin
        sum_value = {SUM_W{1'b0}};
        for (i = 0; i < ROW_LEN; i = i + 1) begin
            sum_value = sum_value + exp_row[(i*EXP_W) +: EXP_W];
        end
    end

endmodule
