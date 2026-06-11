`timescale 1ns/1ps

// Top-level controller for the first full attention simulation pipeline.
// Pipeline: LOAD_QKV -> QK_RUN -> SOFTMAX_RUN -> PV_RUN -> DONE.
module attention_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire       qk_done,
    output reg        latch_inputs,
    output reg        qk_start,
    output reg        capture_softmax,
    output reg        capture_output,
    output reg        valid,
    output reg        done,
    output reg        busy,
    output reg [2:0]  state_dbg
);

    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_QKV    = 3'd1;
    localparam [2:0] QK_RUN      = 3'd2;
    localparam [2:0] SOFTMAX_RUN = 3'd3;
    localparam [2:0] PV_RUN      = 3'd4;
    localparam [2:0] DONE        = 3'd5;

    reg [2:0] state;
    reg qk_started;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            qk_started <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    qk_started <= 1'b0;
                    if (start) begin
                        state <= LOAD_QKV;
                    end
                end

                LOAD_QKV: begin
                    state <= QK_RUN;
                    qk_started <= 1'b0;
                end

                QK_RUN: begin
                    if (!qk_started) begin
                        qk_started <= 1'b1;
                    end else if (qk_done) begin
                        state <= SOFTMAX_RUN;
                        qk_started <= 1'b0;
                    end
                end

                SOFTMAX_RUN: begin
                    state <= PV_RUN;
                end

                PV_RUN: begin
                    state <= DONE;
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    qk_started <= 1'b0;
                end
            endcase
        end
    end

    always @* begin
        latch_inputs = 1'b0;
        qk_start = 1'b0;
        capture_softmax = 1'b0;
        capture_output = 1'b0;
        valid = 1'b0;
        done = 1'b0;
        busy = 1'b0;
        state_dbg = state;

        case (state)
            LOAD_QKV: begin
                latch_inputs = 1'b1;
                busy = 1'b1;
            end
            QK_RUN: begin
                qk_start = !qk_started;
                busy = 1'b1;
            end
            SOFTMAX_RUN: begin
                capture_softmax = 1'b1;
                busy = 1'b1;
            end
            PV_RUN: begin
                capture_output = 1'b1;
                busy = 1'b1;
            end
            DONE: begin
                valid = 1'b1;
                done = 1'b1;
            end
            default: begin
                busy = 1'b0;
            end
        endcase
    end

endmodule
