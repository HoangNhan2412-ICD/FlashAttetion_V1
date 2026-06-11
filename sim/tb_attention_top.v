`timescale 1ns/1ps

module tb_attention_top;
    localparam DATA_W  = 8;
    localparam ACC_W   = 32;
    localparam PROB_W  = 8;
    localparam SEQ_LEN = 8;
    localparam D_MODEL = 8;
    localparam QKV_COUNT = SEQ_LEN * D_MODEL;
    localparam TOLERANCE = 0;

    reg clk;
    reg rst_n;
    reg start;
    reg signed [(QKV_COUNT*DATA_W)-1:0] q_matrix;
    reg signed [(QKV_COUNT*DATA_W)-1:0] k_matrix;
    reg signed [(QKV_COUNT*DATA_W)-1:0] v_matrix;
    wire signed [(QKV_COUNT*ACC_W)-1:0] o_matrix;
    wire valid;
    wire done;
    wire busy;
    wire [2:0] state_dbg;

    reg signed [DATA_W-1:0] q_mem [0:QKV_COUNT-1];
    reg signed [DATA_W-1:0] k_mem [0:QKV_COUNT-1];
    reg signed [DATA_W-1:0] v_mem [0:QKV_COUNT-1];
    reg signed [ACC_W-1:0] expected_mem [0:QKV_COUNT-1];

    integer i;
    integer failures;
    integer cycles;
    integer file_handle;
    integer scan_status;
    integer tmp_value;
    integer loaded_q;
    integer loaded_k;
    integer loaded_v;
    integer loaded_expected;
    integer diff;
    reg signed [ACC_W-1:0] got_value;

    attention_top #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .PROB_W(PROB_W),
        .SEQ_LEN(SEQ_LEN),
        .D_MODEL(D_MODEL)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .q_matrix(q_matrix),
        .k_matrix(k_matrix),
        .v_matrix(v_matrix),
        .o_matrix(o_matrix),
        .valid(valid),
        .done(done),
        .busy(busy),
        .state_dbg(state_dbg)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task load_int8_file;
        input [1023:0] path;
        input integer matrix_id;
        output integer loaded;
        begin
            loaded = 0;
            file_handle = $fopen(path, "r");
            if (file_handle != 0) begin
                for (i = 0; i < QKV_COUNT; i = i + 1) begin
                    scan_status = $fscanf(file_handle, "%d\n", tmp_value);
                    if (scan_status == 1) begin
                        if (matrix_id == 0) begin
                            q_mem[i] = tmp_value[DATA_W-1:0];
                        end else if (matrix_id == 1) begin
                            k_mem[i] = tmp_value[DATA_W-1:0];
                        end else begin
                            v_mem[i] = tmp_value[DATA_W-1:0];
                        end
                    end else begin
                        $display("ERROR: could not read entry %0d from %0s", i, path);
                        loaded = 0;
                        i = QKV_COUNT;
                    end
                end
                $fclose(file_handle);
                if (i == QKV_COUNT) begin
                    loaded = 1;
                end
            end
        end
    endtask

    task load_expected_file;
        output integer loaded;
        begin
            loaded = 0;
            file_handle = $fopen("vectors/golden_output_fixed.mem", "r");
            if (file_handle != 0) begin
                for (i = 0; i < QKV_COUNT; i = i + 1) begin
                    scan_status = $fscanf(file_handle, "%d\n", tmp_value);
                    if (scan_status == 1) begin
                        expected_mem[i] = tmp_value;
                    end else begin
                        $display("ERROR: could not read entry %0d from vectors/golden_output_fixed.mem", i);
                        loaded = 0;
                        i = QKV_COUNT;
                    end
                end
                $fclose(file_handle);
                if (i == QKV_COUNT) begin
                    loaded = 1;
                end
            end
        end
    endtask

    task pack_inputs;
        begin
            for (i = 0; i < QKV_COUNT; i = i + 1) begin
                q_matrix[(i*DATA_W) +: DATA_W] = q_mem[i];
                k_matrix[(i*DATA_W) +: DATA_W] = k_mem[i];
                v_matrix[(i*DATA_W) +: DATA_W] = v_mem[i];
            end
        end
    endtask

    initial begin
        failures = 0;
        q_matrix = {(QKV_COUNT*DATA_W){1'b0}};
        k_matrix = {(QKV_COUNT*DATA_W){1'b0}};
        v_matrix = {(QKV_COUNT*DATA_W){1'b0}};
        rst_n = 1'b0;
        start = 1'b0;

        load_int8_file("vectors/q_input.mem", 0, loaded_q);
        load_int8_file("vectors/k_input.mem", 1, loaded_k);
        load_int8_file("vectors/v_input.mem", 2, loaded_v);
        load_expected_file(loaded_expected);

        if (!(loaded_q && loaded_k && loaded_v && loaded_expected)) begin
            $display("FAIL attention_top: required vector files are missing");
            $display("  q=%0d k=%0d v=%0d expected=%0d", loaded_q, loaded_k, loaded_v, loaded_expected);
            $finish;
        end

        pack_inputs;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        cycles = 0;
        while (!done && cycles < 700) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!done || !valid) begin
            $display("FAIL attention_top: timeout or invalid done, done=%0d valid=%0d state=%0d", done, valid, state_dbg);
            failures = failures + 1;
        end

        for (i = 0; i < QKV_COUNT; i = i + 1) begin
            got_value = o_matrix[(i*ACC_W) +: ACC_W];
            if (got_value >= expected_mem[i]) begin
                diff = got_value - expected_mem[i];
            end else begin
                diff = expected_mem[i] - got_value;
            end

            if (diff > TOLERANCE) begin
                $display("FAIL attention_top O[%0d][%0d]: expected=%0d got=%0d diff=%0d",
                         i / D_MODEL, i % D_MODEL, expected_mem[i], got_value, diff);
                failures = failures + 1;
            end
        end

        if (failures == 0) begin
            $display("tb_attention_top PASS");
            $finish;
        end else begin
            $display("tb_attention_top FAIL: %0d failures", failures);
            $finish;
        end
    end
endmodule
