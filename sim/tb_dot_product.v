`timescale 1ns/1ps

module tb_dot_product;
    localparam DATA_W = 8;
    localparam ACC_W  = 32;
    localparam D_MODEL = 8;

    reg  signed [(D_MODEL*DATA_W)-1:0] q_vec;
    reg  signed [(D_MODEL*DATA_W)-1:0] k_vec;
    wire signed [ACC_W-1:0]            dot_out;

    integer failures;

    dot_product #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .D_MODEL(D_MODEL)
    ) dut (
        .q_vec(q_vec),
        .k_vec(k_vec),
        .dot_out(dot_out)
    );

    task set_q;
        input signed [DATA_W-1:0] q0;
        input signed [DATA_W-1:0] q1;
        input signed [DATA_W-1:0] q2;
        input signed [DATA_W-1:0] q3;
        input signed [DATA_W-1:0] q4;
        input signed [DATA_W-1:0] q5;
        input signed [DATA_W-1:0] q6;
        input signed [DATA_W-1:0] q7;
        begin
            q_vec = {q7, q6, q5, q4, q3, q2, q1, q0};
        end
    endtask

    task set_k;
        input signed [DATA_W-1:0] k0;
        input signed [DATA_W-1:0] k1;
        input signed [DATA_W-1:0] k2;
        input signed [DATA_W-1:0] k3;
        input signed [DATA_W-1:0] k4;
        input signed [DATA_W-1:0] k5;
        input signed [DATA_W-1:0] k6;
        input signed [DATA_W-1:0] k7;
        begin
            k_vec = {k7, k6, k5, k4, k3, k2, k1, k0};
        end
    endtask

    task check;
        input signed [ACC_W-1:0] expected;
        begin
            #1;
            if (dot_out !== expected) begin
                $display("FAIL dot_product: expected=%0d got=%0d", expected, dot_out);
                failures = failures + 1;
            end else begin
                $display("PASS dot_product: dot_out=%0d", dot_out);
            end
        end
    endtask

    initial begin
        failures = 0;

        // [1,2,3,4,5,6,7,8] dot [1,1,1,1,1,1,1,1] = 36
        set_q(8'sd1, 8'sd2, 8'sd3, 8'sd4, 8'sd5, 8'sd6, 8'sd7, 8'sd8);
        set_k(8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1, 8'sd1);
        check(32'sd36);

        // [1,-2,3,-4,5,-6,7,-8] dot [2,3,4,5,6,7,8,9] = -40
        set_q(8'sd1, -8'sd2, 8'sd3, -8'sd4, 8'sd5, -8'sd6, 8'sd7, -8'sd8);
        set_k(8'sd2,  8'sd3, 8'sd4,  8'sd5, 8'sd6,  8'sd7, 8'sd8,  8'sd9);
        check(-32'sd40);

        // [-8,-7,-6,-5,-4,-3,-2,-1] dot [-1,-2,-3,-4,-5,-6,-7,-8] = 120
        set_q(-8'sd8, -8'sd7, -8'sd6, -8'sd5, -8'sd4, -8'sd3, -8'sd2, -8'sd1);
        set_k(-8'sd1, -8'sd2, -8'sd3, -8'sd4, -8'sd5, -8'sd6, -8'sd7, -8'sd8);
        check(32'sd120);

        if (failures == 0) begin
            $display("tb_dot_product PASS");
            $finish;
        end else begin
            $display("tb_dot_product FAIL: %0d failures", failures);
            $finish;
        end
    end
endmodule
