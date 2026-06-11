`timescale 1ns/1ps

// Approximate exp(diff) lookup for non-positive integer score differences.
// Input is expected to be score - row_max, so diff <= 0.
// Output format is unsigned Q8.8, where 1.0 is encoded as 256.
// Values at diff <= -8 are clipped to 0 for this first simple approximation.
module exp_lut #(
    parameter DIFF_W = 32,
    parameter EXP_W  = 16
)(
    input  wire signed [DIFF_W-1:0] diff,
    output reg  [EXP_W-1:0]         exp_value
);

    always @* begin
        if (diff >= 0) begin
            exp_value = 16'd256; // exp(0) ~= 1.0 in Q8.8
        end else begin
            case (-diff)
                32'd1: exp_value = 16'd94;  // round(exp(-1) * 256)
                32'd2: exp_value = 16'd35;  // round(exp(-2) * 256)
                32'd3: exp_value = 16'd13;  // round(exp(-3) * 256)
                32'd4: exp_value = 16'd5;   // round(exp(-4) * 256)
                32'd5: exp_value = 16'd2;   // round(exp(-5) * 256)
                32'd6: exp_value = 16'd1;   // round(exp(-6) * 256)
                32'd7: exp_value = 16'd0;   // clipped
                default: exp_value = 16'd0;
            endcase
        end
    end

endmodule
