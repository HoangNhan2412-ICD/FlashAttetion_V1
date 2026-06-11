# Change Log

## Full attention pipeline PR

- Added `attention_top` to connect QK matmul, row-wise softmax approximation, and PV matmul for the initial 8x8 simulation pipeline.
- Added `pv_matmul` with signed int32 outputs scaled by the Q0.8 probability factor.
- Added `attention_fsm` with `LOAD_QKV`, `QK_RUN`, `SOFTMAX_RUN`, `PV_RUN`, and `DONE` pipeline states.
- Added `tb_attention_top` to compare the integrated output against Python-generated fixed-point golden values.
- Added a Python fixed-point reference and generated `vectors/golden_output_fixed.mem`.

Verification status:

- Verified: one full attention-top smoke simulation in the current environment against fixed-point Python golden output.
- Needs verification: broader randomized tolerance testing, AXI/DDR integration, Vivado synthesis, timing, power, and utilization.

## Softmax approximation PR

- Added `row_max`, `exp_lut`, `row_sum`, and `softmax_approx` for one 8-element score row.
- Documented the initial fixed-point formats: signed int32 score input, unsigned Q8.8 exponential LUT values, 20-bit row sum, and unsigned Q0.8 probabilities.
- Added `tb_softmax_approx` sanity checks for uniform, dominant-score, and mixed rows.
- Updated the verification plan to avoid claiming exact floating-point softmax accuracy.

Verification status:

- Verified: softmax approximation sanity simulation in the current environment.
- Needs verification: broad tolerance comparison against Python, PV matmul, full attention pipeline, Vivado synthesis, timing, power, and utilization.

## QK matmul PR

- Added `qk_matmul` for the 8x8 signed int8 `Score = Q*K^T` stage with signed int32 scores.
- Added a simple `IDLE`, `RUN`, `DONE` FSM around the sequential score computation.
- Added `tb_qk_matmul` to read generated Q/K vector files and compare against Python-generated golden scores when available.
- Extended vector generation to emit `vectors/golden_score.mem` for unscaled QK score checks.
- Updated dataflow and verification documentation for the verified QK stage.

Verification status:

- Verified: `qk_matmul` simulation in the current environment against Python-generated golden scores.
- Needs verification: scale, softmax, PV matmul, full attention pipeline, Vivado synthesis, timing, power, and utilization.

## Basic compute blocks PR

- Added `mac_unit` for signed int8 multiply-accumulate into a signed int32 accumulator.
- Added `dot_product` for an 8-lane signed int8 dot product with signed int32 output.
- Added standalone testbenches for `mac_unit` and `dot_product` using hand-checkable vectors.
- Updated the verification plan to separate verified compute-block checks from future QK matmul work.

Verification status:

- Verified: `mac_unit` and `dot_product` simulations in the current environment when Icarus Verilog is available and the listed commands pass.
- Needs verification: QK matmul, softmax, PV matmul, full attention pipeline, Vivado synthesis, timing, power, and utilization.

## Skeleton setup PR

- Added initial project documentation for goals, architecture, dataflow, and verification planning.
- Added a Python reference model for floating-point scaled dot-product attention.
- Added a deterministic vector generator for `Q`, `K`, `V`, and golden attention output files.
- Added ignore rules for Python artifacts, simulation outputs, and Vivado build products.

Verification status:

- Verified: Python reference model smoke test and vector generation in the current environment.
- Needs verification: RTL simulation, Vivado synthesis, timing, power, and utilization.
