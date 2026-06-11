`timescale 1ns/1ps

// First integrated 8x8 self-attention pipeline for simulation bring-up.
// Pipeline: LOAD_QKV -> QK_RUN -> SOFTMAX_RUN -> PV_RUN -> DONE.
//
// Inputs Q/K/V are signed int8 matrices packed row-major. Output O is signed
// int32 and remains scaled by the Q0.8 probability factor (255 ~= 1.0).
module attention_top #(
    parameter DATA_W  = 8,
    parameter ACC_W   = 32,
    parameter PROB_W  = 8,
    parameter EXP_W   = 16,
    parameter SUM_W   = 20,
    parameter SEQ_LEN = 8,
    parameter D_MODEL = 8
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      start,
    input  wire signed [(SEQ_LEN*D_MODEL*DATA_W)-1:0] q_matrix,
    input  wire signed [(SEQ_LEN*D_MODEL*DATA_W)-1:0] k_matrix,
    input  wire signed [(SEQ_LEN*D_MODEL*DATA_W)-1:0] v_matrix,
    output reg  signed [(SEQ_LEN*D_MODEL*ACC_W)-1:0]  o_matrix,
    output wire                                      valid,
    output wire                                      done,
    output wire                                      busy,
    output wire [2:0]                                state_dbg
);

    localparam SCORE_COUNT = SEQ_LEN * SEQ_LEN;
    localparam QKV_COUNT   = SEQ_LEN * D_MODEL;

    reg signed [(QKV_COUNT*DATA_W)-1:0] q_reg;
    reg signed [(QKV_COUNT*DATA_W)-1:0] k_reg;
    reg signed [(QKV_COUNT*DATA_W)-1:0] v_reg;
    reg [(SCORE_COUNT*PROB_W)-1:0] prob_matrix_reg;

    wire latch_inputs;
    wire qk_start;
    wire capture_softmax;
    wire capture_output;
    wire qk_busy;
    wire qk_done;
    wire signed [(SCORE_COUNT*ACC_W)-1:0] score_matrix;
    wire [(SCORE_COUNT*PROB_W)-1:0] prob_matrix_wire;
    wire signed [(QKV_COUNT*ACC_W)-1:0] pv_out_wire;

    attention_fsm fsm_i (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .qk_done(qk_done),
        .latch_inputs(latch_inputs),
        .qk_start(qk_start),
        .capture_softmax(capture_softmax),
        .capture_output(capture_output),
        .valid(valid),
        .done(done),
        .busy(busy),
        .state_dbg(state_dbg)
    );

    qk_matmul #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .SEQ_LEN(SEQ_LEN),
        .D_MODEL(D_MODEL)
    ) qk_matmul_i (
        .clk(clk),
        .rst_n(rst_n),
        .start(qk_start),
        .q_matrix(q_reg),
        .k_matrix(k_reg),
        .score_matrix(score_matrix),
        .busy(qk_busy),
        .done(qk_done)
    );

    genvar row;
    generate
        for (row = 0; row < SEQ_LEN; row = row + 1) begin : gen_softmax_rows
            wire signed [(SEQ_LEN*ACC_W)-1:0] score_row;
            wire [(SEQ_LEN*PROB_W)-1:0] prob_row;
            wire signed [ACC_W-1:0] unused_max;
            wire [SUM_W-1:0] unused_sum;

            assign score_row = score_matrix[(row*SEQ_LEN*ACC_W) +: (SEQ_LEN*ACC_W)];
            assign prob_matrix_wire[(row*SEQ_LEN*PROB_W) +: (SEQ_LEN*PROB_W)] = prob_row;

            softmax_approx #(
                .ROW_LEN(SEQ_LEN),
                .SCORE_W(ACC_W),
                .EXP_W(EXP_W),
                .SUM_W(SUM_W),
                .PROB_W(PROB_W)
            ) softmax_approx_i (
                .score_row(score_row),
                .prob_row(prob_row),
                .max_value(unused_max),
                .exp_sum(unused_sum)
            );
        end
    endgenerate

    pv_matmul #(
        .DATA_W(DATA_W),
        .PROB_W(PROB_W),
        .ACC_W(ACC_W),
        .SEQ_LEN(SEQ_LEN),
        .D_MODEL(D_MODEL)
    ) pv_matmul_i (
        .prob_matrix(prob_matrix_reg),
        .v_matrix(v_reg),
        .o_matrix(pv_out_wire)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_reg <= {(QKV_COUNT*DATA_W){1'b0}};
            k_reg <= {(QKV_COUNT*DATA_W){1'b0}};
            v_reg <= {(QKV_COUNT*DATA_W){1'b0}};
            prob_matrix_reg <= {(SCORE_COUNT*PROB_W){1'b0}};
            o_matrix <= {(QKV_COUNT*ACC_W){1'b0}};
        end else begin
            if (latch_inputs) begin
                q_reg <= q_matrix;
                k_reg <= k_matrix;
                v_reg <= v_matrix;
                prob_matrix_reg <= {(SCORE_COUNT*PROB_W){1'b0}};
                o_matrix <= {(QKV_COUNT*ACC_W){1'b0}};
            end

            if (capture_softmax) begin
                prob_matrix_reg <= prob_matrix_wire;
            end

            if (capture_output) begin
                o_matrix <= pv_out_wire;
            end
        end
    end

endmodule
