`timescale 1ns/1ps

// Combinational row maximum for an 8-element signed int32 score row.
module row_max #(
    parameter ROW_LEN = 8,
    parameter SCORE_W = 32
)(
    input  wire signed [(ROW_LEN*SCORE_W)-1:0] score_row,
    output reg  signed [SCORE_W-1:0]           max_value
);

    integer i;
    reg signed [SCORE_W-1:0] elem;

    always @* begin
        max_value = score_row[0 +: SCORE_W];
        for (i = 1; i < ROW_LEN; i = i + 1) begin
            elem = score_row[(i*SCORE_W) +: SCORE_W];
            if (elem > max_value) begin
                max_value = elem;
            end
        end
    end

endmodule
