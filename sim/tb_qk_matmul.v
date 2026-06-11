`timescale 1ns/1ps

module tb_qk_matmul;
    localparam DATA_W  = 8;
    localparam ACC_W   = 32;
    localparam SEQ_LEN = 8;
    localparam D_MODEL = 8;
    localparam QK_COUNT = SEQ_LEN * D_MODEL;
    localparam SCORE_COUNT = SEQ_LEN * SEQ_LEN;

    reg clk;
    reg rst_n;
    reg start;
    reg signed [(QK_COUNT*DATA_W)-1:0] q_matrix;
    reg signed [(QK_COUNT*DATA_W)-1:0] k_matrix;
    wire signed [(SCORE_COUNT*ACC_W)-1:0] score_matrix;
    wire busy;
    wire done;

    reg signed [DATA_W-1:0] q_mem [0:QK_COUNT-1];
    reg signed [DATA_W-1:0] k_mem [0:QK_COUNT-1];
    reg signed [ACC_W-1:0] expected_score [0:SCORE_COUNT-1];

    integer failures;
    integer i;
    integer row;
    integer col;
    integer dim;
    integer cycles;
    integer file_handle;
    integer scan_status;
    integer tmp_value;
    integer used_python_golden;
    integer used_input_files;
    reg signed [ACC_W-1:0] got_score;
    reg signed [ACC_W-1:0] expected_value;

    qk_matmul #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .SEQ_LEN(SEQ_LEN),
        .D_MODEL(D_MODEL)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .q_matrix(q_matrix),
        .k_matrix(k_matrix),
        .score_matrix(score_matrix),
        .busy(busy),
        .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task load_int8_file;
        input [1023:0] path;
        input integer load_q;
        output integer loaded;
        begin
            loaded = 0;
            file_handle = $fopen(path, "r");
            if (file_handle != 0) begin
                for (i = 0; i < QK_COUNT; i = i + 1) begin
                    scan_status = $fscanf(file_handle, "%d\n", tmp_value);
                    if (scan_status == 1) begin
                        if (load_q) begin
                            q_mem[i] = tmp_value[DATA_W-1:0];
                        end else begin
                            k_mem[i] = tmp_value[DATA_W-1:0];
                        end
                    end else begin
                        $display("ERROR: could not read entry %0d from %0s", i, path);
                        loaded = 0;
                        i = QK_COUNT;
                    end
                end
                $fclose(file_handle);
                if (i == QK_COUNT) begin
                    loaded = 1;
                end
            end
        end
    endtask

    task load_golden_score_file;
        output integer loaded;
        begin
            loaded = 0;
            file_handle = $fopen("vectors/golden_score.mem", "r");
            if (file_handle != 0) begin
                for (i = 0; i < SCORE_COUNT; i = i + 1) begin
                    scan_status = $fscanf(file_handle, "%d\n", tmp_value);
                    if (scan_status == 1) begin
                        expected_score[i] = tmp_value;
                    end else begin
                        $display("ERROR: could not read entry %0d from vectors/golden_score.mem", i);
                        loaded = 0;
                        i = SCORE_COUNT;
                    end
                end
                $fclose(file_handle);
                if (i == SCORE_COUNT) begin
                    loaded = 1;
                end
            end
        end
    endtask

    task load_default_vectors;
        begin
            for (i = 0; i < QK_COUNT; i = i + 1) begin
                q_mem[i] = (i % 8) - 4;
                k_mem[i] = 3 - (i % 8);
            end
        end
    endtask

    task pack_inputs;
        begin
            for (i = 0; i < QK_COUNT; i = i + 1) begin
                q_matrix[(i*DATA_W) +: DATA_W] = q_mem[i];
                k_matrix[(i*DATA_W) +: DATA_W] = k_mem[i];
            end
        end
    endtask

    task compute_expected_scores;
        begin
            for (row = 0; row < SEQ_LEN; row = row + 1) begin
                for (col = 0; col < SEQ_LEN; col = col + 1) begin
                    expected_value = {ACC_W{1'b0}};
                    for (dim = 0; dim < D_MODEL; dim = dim + 1) begin
                        expected_value = expected_value +
                            (q_mem[row*D_MODEL + dim] * k_mem[col*D_MODEL + dim]);
                    end
                    expected_score[row*SEQ_LEN + col] = expected_value;
                end
            end
        end
    endtask

    initial begin
        failures = 0;
        q_matrix = {(QK_COUNT*DATA_W){1'b0}};
        k_matrix = {(QK_COUNT*DATA_W){1'b0}};
        rst_n = 1'b0;
        start = 1'b0;
        used_python_golden = 0;
        used_input_files = 0;

        load_int8_file("vectors/q_input.mem", 1, scan_status);
        if (scan_status == 0) begin
            $display("vectors/q_input.mem not found; using built-in Q/K vectors");
            load_default_vectors;
        end else begin
            load_int8_file("vectors/k_input.mem", 0, scan_status);
            if (scan_status == 0) begin
                $display("vectors/k_input.mem not found; using built-in Q/K vectors");
                load_default_vectors;
            end else begin
                used_input_files = 1;
            end
        end

        if (used_input_files) begin
            load_golden_score_file(scan_status);
            if (scan_status == 1) begin
                used_python_golden = 1;
                $display("Using Python golden scores from vectors/golden_score.mem");
            end else begin
                $display("vectors/golden_score.mem not found; computing expected scores in testbench");
                compute_expected_scores;
            end
        end else begin
            compute_expected_scores;
        end

        pack_inputs;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        cycles = 0;
        while (!done && cycles < 600) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!done) begin
            $display("FAIL qk_matmul: timeout waiting for done");
            failures = failures + 1;
        end

        for (i = 0; i < SCORE_COUNT; i = i + 1) begin
            got_score = score_matrix[(i*ACC_W) +: ACC_W];
            if (got_score !== expected_score[i]) begin
                $display("FAIL qk_matmul score[%0d][%0d]: expected=%0d got=%0d",
                         i / SEQ_LEN, i % SEQ_LEN, expected_score[i], got_score);
                failures = failures + 1;
            end
        end

        if (failures == 0) begin
            if (used_python_golden) begin
                $display("tb_qk_matmul PASS using Python golden scores");
            end else begin
                $display("tb_qk_matmul PASS using testbench-computed scores");
            end
            $finish;
        end else begin
            $display("tb_qk_matmul FAIL: %0d failures", failures);
            $finish;
        end
    end
endmodule
