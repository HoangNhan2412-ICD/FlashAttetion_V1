`timescale 1ns/1ps

// Combinational P*V multiply for the first fixed-point attention pipeline.
// prob_matrix uses unsigned Q0.8 probabilities where 255 ~= 1.0.
// o_matrix stores signed int32 values still scaled by 255.
module pv_matmul #(
    parameter DATA_W  = 8,
    parameter PROB_W  = 8,
    parameter ACC_W   = 32,
    parameter SEQ_LEN = 8,
    parameter D_MODEL = 8
)(
    input  wire [(SEQ_LEN*SEQ_LEN*PROB_W)-1:0]       prob_matrix,
    input  wire signed [(SEQ_LEN*D_MODEL*DATA_W)-1:0] v_matrix,
    output reg  signed [(SEQ_LEN*D_MODEL*ACC_W)-1:0]  o_matrix
);

    integer row;
    integer dim;
    integer token;
    reg signed [ACC_W-1:0] acc;
    reg [PROB_W-1:0] prob_elem;
    reg signed [DATA_W-1:0] v_elem;

    always @* begin
        o_matrix = {(SEQ_LEN*D_MODEL*ACC_W){1'b0}};
        for (row = 0; row < SEQ_LEN; row = row + 1) begin
            for (dim = 0; dim < D_MODEL; dim = dim + 1) begin
                acc = {ACC_W{1'b0}};
                for (token = 0; token < SEQ_LEN; token = token + 1) begin
                    prob_elem = prob_matrix[((row*SEQ_LEN + token)*PROB_W) +: PROB_W];
                    v_elem = v_matrix[((token*D_MODEL + dim)*DATA_W) +: DATA_W];
                    acc = acc + ($signed({1'b0, prob_elem}) * v_elem);
                end
                o_matrix[((row*D_MODEL + dim)*ACC_W) +: ACC_W] = acc;
            end
        end
    end

endmodule
