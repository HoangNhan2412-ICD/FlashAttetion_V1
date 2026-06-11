`timescale 1ns/1ps

// Signed multiply-accumulate helper for attention dot products.
// Computes acc_out = acc_in + (a * b).
module mac_unit #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  signed [DATA_W-1:0] a,
    input  signed [DATA_W-1:0] b,
    input  signed [ACC_W-1:0]  acc_in,
    output signed [ACC_W-1:0]  acc_out
);

    wire signed [(2*DATA_W)-1:0] product;

    assign product = a * b;
    assign acc_out = acc_in + {{(ACC_W-(2*DATA_W)){product[(2*DATA_W)-1]}}, product};

endmodule
