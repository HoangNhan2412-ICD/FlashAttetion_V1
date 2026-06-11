`timescale 1ns/1ps

module tb_mac_unit;
    localparam DATA_W = 8;
    localparam ACC_W  = 32;

    reg  signed [DATA_W-1:0] a;
    reg  signed [DATA_W-1:0] b;
    reg  signed [ACC_W-1:0]  acc_in;
    wire signed [ACC_W-1:0]  acc_out;

    integer failures;

    mac_unit #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .a(a),
        .b(b),
        .acc_in(acc_in),
        .acc_out(acc_out)
    );

    task check;
        input signed [DATA_W-1:0] test_a;
        input signed [DATA_W-1:0] test_b;
        input signed [ACC_W-1:0]  test_acc_in;
        input signed [ACC_W-1:0]  expected;
        begin
            a = test_a;
            b = test_b;
            acc_in = test_acc_in;
            #1;
            if (acc_out !== expected) begin
                $display("FAIL mac_unit: a=%0d b=%0d acc_in=%0d expected=%0d got=%0d",
                         test_a, test_b, test_acc_in, expected, acc_out);
                failures = failures + 1;
            end else begin
                $display("PASS mac_unit: a=%0d b=%0d acc_in=%0d acc_out=%0d",
                         test_a, test_b, test_acc_in, acc_out);
            end
        end
    endtask

    initial begin
        failures = 0;

        check(8'sd3,   8'sd4,   32'sd0,    32'sd12);
        check(-8'sd3,  8'sd4,   32'sd10,  -32'sd2);
        check(8'sd7,  -8'sd6,  -32'sd5,  -32'sd47);
        check(-8'sd8, -8'sd8,   32'sd100,  32'sd164);

        if (failures == 0) begin
            $display("tb_mac_unit PASS");
            $finish;
        end else begin
            $display("tb_mac_unit FAIL: %0d failures", failures);
            $finish;
        end
    end
endmodule
