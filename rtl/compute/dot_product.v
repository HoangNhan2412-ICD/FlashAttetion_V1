`timescale 1ns/1ps

// Combinational signed dot product for one Q row and one K row.
// Vector packing convention:
//   q_vec[(i*DATA_W) +: DATA_W] is q[i]
//   k_vec[(i*DATA_W) +: DATA_W] is k[i]
// for i = 0..D_MODEL-1.
module dot_product #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter D_MODEL = 8
)(
    input  signed [(D_MODEL*DATA_W)-1:0] q_vec,
    input  signed [(D_MODEL*DATA_W)-1:0] k_vec,
    output signed [ACC_W-1:0]            dot_out
);

    integer i;
    reg signed [ACC_W-1:0] acc;
    reg signed [DATA_W-1:0] q_elem;
    reg signed [DATA_W-1:0] k_elem;

    always @* begin
        acc = {ACC_W{1'b0}};
        for (i = 0; i < D_MODEL; i = i + 1) begin
            q_elem = q_vec[(i*DATA_W) +: DATA_W];
            k_elem = k_vec[(i*DATA_W) +: DATA_W];
            acc = acc + (q_elem * k_elem);
        end
    end

    assign dot_out = acc;

endmodule
