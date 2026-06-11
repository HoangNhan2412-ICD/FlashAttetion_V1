`timescale 1ns/1ps

module tb_softmax_approx;
    localparam ROW_LEN = 8;
    localparam SCORE_W = 32;
    localparam EXP_W   = 16;
    localparam SUM_W   = 20;
    localparam PROB_W  = 8;

    reg signed [(ROW_LEN*SCORE_W)-1:0] score_row;
    wire [(ROW_LEN*PROB_W)-1:0] prob_row;
    wire signed [SCORE_W-1:0] max_value;
    wire [SUM_W-1:0] exp_sum;

    integer failures;
    integer prob_total;
    integer i;

    softmax_approx #(
        .ROW_LEN(ROW_LEN),
        .SCORE_W(SCORE_W),
        .EXP_W(EXP_W),
        .SUM_W(SUM_W),
        .PROB_W(PROB_W)
    ) dut (
        .score_row(score_row),
        .prob_row(prob_row),
        .max_value(max_value),
        .exp_sum(exp_sum)
    );

    task set_scores;
        input signed [SCORE_W-1:0] s0;
        input signed [SCORE_W-1:0] s1;
        input signed [SCORE_W-1:0] s2;
        input signed [SCORE_W-1:0] s3;
        input signed [SCORE_W-1:0] s4;
        input signed [SCORE_W-1:0] s5;
        input signed [SCORE_W-1:0] s6;
        input signed [SCORE_W-1:0] s7;
        begin
            score_row = {s7, s6, s5, s4, s3, s2, s1, s0};
        end
    endtask

    function [PROB_W-1:0] prob_at;
        input integer idx;
        begin
            prob_at = prob_row[(idx*PROB_W) +: PROB_W];
        end
    endfunction

    task check_prob_sum;
        begin
            prob_total = 0;
            for (i = 0; i < ROW_LEN; i = i + 1) begin
                prob_total = prob_total + prob_at(i);
            end
            if (prob_total < 248 || prob_total > 255) begin
                $display("FAIL softmax sum: expected approximately 255, got %0d", prob_total);
                failures = failures + 1;
            end else begin
                $display("PASS softmax sum: %0d", prob_total);
            end
        end
    endtask

    initial begin
        failures = 0;

        // Equal scores should produce nearly uniform Q0.8 probabilities.
        set_scores(32'sd5, 32'sd5, 32'sd5, 32'sd5, 32'sd5, 32'sd5, 32'sd5, 32'sd5);
        #1;
        if (max_value !== 32'sd5) begin
            $display("FAIL equal row max: expected 5, got %0d", max_value);
            failures = failures + 1;
        end
        for (i = 0; i < ROW_LEN; i = i + 1) begin
            if (prob_at(i) < 8'd31 || prob_at(i) > 8'd32) begin
                $display("FAIL equal prob[%0d]: expected 31..32, got %0d", i, prob_at(i));
                failures = failures + 1;
            end
        end
        check_prob_sum;

        // A clearly dominant max score should receive most of the probability.
        set_scores(32'sd10, 32'sd0, -32'sd1, -32'sd2, -32'sd3, -32'sd4, -32'sd5, -32'sd6);
        #1;
        if (max_value !== 32'sd10) begin
            $display("FAIL dominant row max: expected 10, got %0d", max_value);
            failures = failures + 1;
        end
        if (prob_at(0) < 8'd240) begin
            $display("FAIL dominant probability: expected prob[0] >= 240, got %0d", prob_at(0));
            failures = failures + 1;
        end
        for (i = 1; i < ROW_LEN; i = i + 1) begin
            if (prob_at(i) > 8'd5) begin
                $display("FAIL clipped tail prob[%0d]: expected <= 5, got %0d", i, prob_at(i));
                failures = failures + 1;
            end
        end
        check_prob_sum;

        // Mixed small differences should preserve ordering around the maximum.
        set_scores(-32'sd3, -32'sd2, -32'sd1, 32'sd0, -32'sd1, -32'sd2, -32'sd3, -32'sd4);
        #1;
        if (max_value !== 32'sd0) begin
            $display("FAIL mixed row max: expected 0, got %0d", max_value);
            failures = failures + 1;
        end
        if (!(prob_at(3) > prob_at(2) && prob_at(2) > prob_at(1) && prob_at(1) > prob_at(0))) begin
            $display("FAIL mixed ordering left side: p3=%0d p2=%0d p1=%0d p0=%0d",
                     prob_at(3), prob_at(2), prob_at(1), prob_at(0));
            failures = failures + 1;
        end
        if (prob_at(2) !== prob_at(4)) begin
            $display("FAIL symmetric probabilities: p2=%0d p4=%0d", prob_at(2), prob_at(4));
            failures = failures + 1;
        end
        check_prob_sum;

        if (failures == 0) begin
            $display("tb_softmax_approx PASS");
            $finish;
        end else begin
            $display("tb_softmax_approx FAIL: %0d failures", failures);
            $finish;
        end
    end
endmodule
