`timescale 1ns/1ps

// Sequential Q*K^T score-matrix engine for the initial 8x8 attention tile.
//
// Packing convention:
//   q_matrix[((row*D_MODEL + dim)*DATA_W) +: DATA_W] is Q[row][dim]
//   k_matrix[((row*D_MODEL + dim)*DATA_W) +: DATA_W] is K[row][dim]
//   score_matrix[((q_row*SEQ_LEN + k_row)*ACC_W) +: ACC_W] is Score[q_row][k_row]
//
// The datapath computes one signed int8 product per cycle and accumulates into
// signed int32. For the default 8x8 tile this takes 8*8*8 RUN cycles.
module qk_matmul #(
    parameter DATA_W  = 8,
    parameter ACC_W   = 32,
    parameter SEQ_LEN = 8,
    parameter D_MODEL = 8
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      start,
    input  wire signed [(SEQ_LEN*D_MODEL*DATA_W)-1:0] q_matrix,
    input  wire signed [(SEQ_LEN*D_MODEL*DATA_W)-1:0] k_matrix,
    output reg  signed [(SEQ_LEN*SEQ_LEN*ACC_W)-1:0]  score_matrix,
    output reg                                       busy,
    output reg                                       done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN  = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] q_row;
    reg [3:0] k_row;
    reg [3:0] dim_idx;
    reg signed [ACC_W-1:0] acc;

    wire signed [DATA_W-1:0] q_elem;
    wire signed [DATA_W-1:0] k_elem;
    wire signed [(2*DATA_W)-1:0] product;
    wire signed [ACC_W-1:0] product_ext;
    wire signed [ACC_W-1:0] next_acc;

    assign q_elem = q_matrix[((q_row*D_MODEL + dim_idx)*DATA_W) +: DATA_W];
    assign k_elem = k_matrix[((k_row*D_MODEL + dim_idx)*DATA_W) +: DATA_W];
    assign product = q_elem * k_elem;
    assign product_ext = {{(ACC_W-(2*DATA_W)){product[(2*DATA_W)-1]}}, product};
    assign next_acc = acc + product_ext;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            q_row <= 4'd0;
            k_row <= 4'd0;
            dim_idx <= 4'd0;
            acc <= {ACC_W{1'b0}};
            score_matrix <= {(SEQ_LEN*SEQ_LEN*ACC_W){1'b0}};
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= RUN;
                        q_row <= 4'd0;
                        k_row <= 4'd0;
                        dim_idx <= 4'd0;
                        acc <= {ACC_W{1'b0}};
                        score_matrix <= {(SEQ_LEN*SEQ_LEN*ACC_W){1'b0}};
                        busy <= 1'b1;
                    end
                end

                RUN: begin
                    busy <= 1'b1;
                    done <= 1'b0;

                    if (dim_idx == (D_MODEL-1)) begin
                        score_matrix[((q_row*SEQ_LEN + k_row)*ACC_W) +: ACC_W] <= next_acc;
                        acc <= {ACC_W{1'b0}};
                        dim_idx <= 4'd0;

                        if (k_row == (SEQ_LEN-1)) begin
                            k_row <= 4'd0;
                            if (q_row == (SEQ_LEN-1)) begin
                                q_row <= 4'd0;
                                state <= DONE;
                                busy <= 1'b0;
                                done <= 1'b1;
                            end else begin
                                q_row <= q_row + 4'd1;
                            end
                        end else begin
                            k_row <= k_row + 4'd1;
                        end
                    end else begin
                        acc <= next_acc;
                        dim_idx <= dim_idx + 4'd1;
                    end
                end

                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
