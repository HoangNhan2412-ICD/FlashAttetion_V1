Bạn là coding agent hỗ trợ phát triển dự án:

FlashAttention-Inspired Streaming Transformer Accelerator on FPGA

Mục tiêu dự án:

* Xây dựng accelerator self-attention lấy cảm hứng từ FlashAttention.
* Bản đầu tiên chỉ cần chạy simulation đúng.
* Dùng Verilog RTL, không dùng SystemVerilog phức tạp nếu không cần.
* Dữ liệu bản đầu:

  * SEQ_LEN = 8
  * D_MODEL = 8
  * Q/K/V là int8
  * Accumulator dùng int32
  * Softmax dùng fixed-point approximation
* Chưa cần triển khai full Transformer.
* Chưa cần Wq/Wk/Wv ở milestone đầu. Input top module nhận trực tiếp Q, K, V.

Quy tắc quan trọng:

1. Không bịa số liệu synthesis, timing, power, resource.
2. Chưa có report thật thì ghi “Needs verification”.
3. Không commit thư mục Vivado build như .Xil, .runs, .cache.
4. Không sửa RTL lớn một lần. Mỗi PR chỉ nên làm một phần rõ ràng.
5. Mọi module phải có testbench hoặc ít nhất có kế hoạch test.
6. Mọi thay đổi đáng kể phải cập nhật docs/change_log.md.
7. Khi viết docs phải nói rõ phần nào đã verified, phần nào chưa verified.
8. Ưu tiên code dễ hiểu, dễ debug hơn tối ưu quá sớm.
9. Không dùng IP Vivado phức tạp ở milestone đầu.
10. Dự án chạy được simulation trước, synthesize sau.

Cấu trúc repo cần tạo:

* rtl/top/attention_top.v
* rtl/buffers/q_buffer.v
* rtl/buffers/k_buffer.v
* rtl/buffers/v_buffer.v
* rtl/buffers/o_buffer.v
* rtl/compute/mac_unit.v
* rtl/compute/dot_product.v
* rtl/compute/qk_matmul.v
* rtl/compute/pv_matmul.v
* rtl/compute/scale_unit.v
* rtl/softmax/row_max.v
* rtl/softmax/exp_lut.v
* rtl/softmax/row_sum.v
* rtl/softmax/softmax_approx.v
* rtl/control/attention_fsm.v
* rtl/control/tile_scheduler.v
* rtl/common/simple_fifo.v
* rtl/common/bram_1p.v
* sim/tb_attention_top.v
* sim/tb_qk_matmul.v
* sim/tb_softmax_approx.v
* sim/tb_pv_matmul.v
* model/attention_ref.py
* model/fixed_point_ref.py
* model/generate_vectors.py
* vectors/q_input.mem
* vectors/k_input.mem
* vectors/v_input.mem
* vectors/golden_output.mem
* scripts/run_sim.bat
* scripts/run_sim.sh
* scripts/run_vivado_synth.bat
* scripts/run_vivado_synth.tcl
* scripts/parse_vivado_reports.py
* docs/architecture.md
* docs/dataflow.md
* docs/fixed_point.md
* docs/verification_plan.md
* docs/synthesis_report.md
* docs/known_issues.md
* docs/change_log.md

Milestone 1:

* Tạo skeleton repo.
* Tạo README.md giải thích mục tiêu.
* Tạo docs/architecture.md mô tả pipeline:
  Q buffer → K buffer → V buffer → QK matmul → softmax approximation → PV matmul → output buffer.
* Tạo model/attention_ref.py để tính attention bằng Python.
* Tạo model/generate_vectors.py để sinh Q/K/V/golden output.
* Tạo rtl/compute/mac_unit.v và testbench tương ứng.
* Tạo scripts/run_sim.bat để chạy simulation nếu có Icarus Verilog trong PATH.
* Không cần Vivado synthesis ở milestone 1 nếu chưa đủ RTL.

Milestone 2:

* Implement dot_product.v.
* Implement qk_matmul.v.
* Test qk_matmul bằng vector nhỏ.
* So sánh output với Python golden score.
* Cập nhật docs/verification_plan.md.

Milestone 3:

* Implement softmax approximation:
  row_max.v
  exp_lut.v
  row_sum.v
  softmax_approx.v
* Ghi rõ fixed-point format trong docs/fixed_point.md.
* Test riêng softmax approximation.
* Không claim softmax chính xác tuyệt đối; ghi rõ là approximation.

Milestone 4:

* Implement pv_matmul.v.
* Implement attention_top.v.
* Test full attention pipeline với Q/K/V 8x8.
* So sánh output với Python trong tolerance cho phép.

Milestone 5:

* Tạo Vivado synthesis flow cho KV260 hoặc part xck26-sfvc784-2LV-c.
* Clock target 100 MHz.
* Xuất utilization/timing report vào reports/vivado.
* Tạo parse_vivado_reports.py.
* Cập nhật docs/synthesis_report.md.
* Chỉ ghi số liệu thật nếu report tồn tại.

Nhiệm vụ ngay bây giờ:

1. Đọc repo hiện tại.
2. Nếu repo trống, tạo cấu trúc thư mục như trên.
3. Tạo AGENTS.md theo các quy tắc này.
4. Tạo README.md.
5. Tạo docs ban đầu.
6. Tạo Python reference model và vector generator.
7. Tạo RTL đầu tiên cho mac_unit.v và dot_product.v.
8. Tạo testbench đơn giản.
9. Tạo scripts/run_sim.bat.
10. Chạy các test có thể chạy trong môi trường hiện tại.
11. Không bịa kết quả nếu không chạy được tool.
12. Commit thay đổi với message rõ ràng.
