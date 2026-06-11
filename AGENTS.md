Project Scope

This repository implements a FlashAttention-Inspired Streaming Transformer Attention Core in Verilog.

The current goal is testbench-only core verification.

This project does not need:

FPGA board deployment
SoC integration
AXI
DDR
DMA
Linux driver
Bitstream generation
Real hardware execution
Full Transformer encoder
Multi-head attention
Wq/Wk/Wv projection layers

The only required goal is:

Q/K/V input vectors
→ FlashAttention-inspired streaming attention RTL core
→ Verilog testbench
→ compare against Python golden output
→ PASS/FAIL
Main Technical Target

Default configuration:

SEQ_LEN = 8
D_MODEL = 8
TILE_N  = 4
DATA_W  = 8     signed int8 Q/K/V
ACC_W   = 32    signed score accumulator
EXP_W   = 16    fixed-point exp / softmax approximation
OUT_W   = 32    output accumulator

The mathematical target is self-attention:

Score = Q × K^T
P     = softmax(Score)
O     = P × V

The final RTL should be FlashAttention-inspired:

For each Q row:
    process K/V by tile
    compute score tile
    update online row max
    update online softmax sum
    update output accumulator
    emit output row

The streaming version should avoid relying on a full stored probability matrix when possible.

Verification Priority

Correctness is more important than optimization.

Priority order:

Python golden model correctness
RTL module-level correctness
Full streaming attention testbench correctness
Fixed-point error tolerance documentation
Multiple deterministic test cases
Optional Vivado simulation script

Vivado synthesis is optional and not required for the current milestone.

Required Core Files

Important Python model files:

model/generate_vectors.py
model/attention_ref.py
model/streaming_attention_ref.py
model/compare_offline_vs_streaming.py

Important RTL files:

rtl/top/streaming_attention_top.v
rtl/control/streaming_attention_fsm.v
rtl/compute/score_tile_engine.v
rtl/compute/weighted_value_accumulator.v
rtl/softmax/online_softmax_update.v

Existing offline/reference RTL may remain:

rtl/top/attention_top.v
rtl/compute/mac_unit.v
rtl/compute/dot_product.v
rtl/compute/qk_matmul.v
rtl/compute/pv_matmul.v
rtl/softmax/row_max.v
rtl/softmax/exp_lut.v
rtl/softmax/row_sum.v
rtl/softmax/softmax_approx.v

Important simulation files:

sim/tb_mac_unit.v
sim/tb_dot_product.v
sim/tb_qk_matmul.v
sim/tb_softmax_approx.v
sim/tb_attention_top.v
sim/tb_streaming_attention_top.v

Important vector files:

vectors/q_input.mem
vectors/k_input.mem
vectors/v_input.mem
vectors/golden_score.mem
vectors/golden_output.mem
vectors/golden_output_fixed.mem
vectors/streaming_golden_output.mem

Important report/output files:

reports/sim/streaming_rtl_output.mem
reports/sim/compare_result.txt
Required Testbench Behavior

The main testbench is:

sim/tb_streaming_attention_top.v

It must:

Load Q/K/V vectors.
Drive the streaming attention core.
Assert start.
Wait for done.
Collect output matrix O.
Compare RTL output against golden output.
Use a documented tolerance for fixed-point approximation.
Print clear PASS or FAIL.
If FAIL, print:
mismatch count
max absolute error
first failing index
expected value
actual value

Expected output style:

tb_streaming_attention_top PASS
mismatch_count = 0
max_abs_error = ...

or:

tb_streaming_attention_top FAIL
mismatch_count = ...
max_abs_error = ...
Fixed-Point Rules

All fixed-point formats must be documented in:

docs/fixed_point.md

Do not claim exact floating-point equivalence.

If softmax uses LUT or approximation, document:

input range
output format
scaling factor
rounding behavior
saturation behavior
allowed tolerance

If output comparison is approximate, write the tolerance clearly in:

testbench comments
docs/verification_plan.md
README.md
Documentation Rules

Always update documentation when functionality changes.

Important docs:

README.md
docs/architecture.md
docs/dataflow.md
docs/fixed_point.md
docs/verification_plan.md
docs/change_log.md

Do not overfocus on synthesis reports because this project is currently TB-only.

Only create or update synthesis documentation if specifically requested.

Do Not Fabricate Results

Never invent:

simulation PASS results
synthesis results
timing numbers
LUT/FF/BRAM/DSP numbers
power numbers
board execution claims

If a test was not run, write:

Needs verification

If Vivado is unavailable, write:

Vivado simulation requires local verification.
Artifact Rules

Never commit generated tool artifacts:

xsim.dir/
.Xil/
*.jou
*.log
*.wdb
*.pb
*.vvp
*.vcd
*.fst
*.str
*.dcp
*.bit
*.ltx
*.xpr
*.runs/
*.cache/

Generated reports may be committed only if explicitly requested.

Preferred Simulation Flow

Preferred Windows local simulation:

scripts\run_core_tb_vivado.bat

This script should focus on:

tb_streaming_attention_top

A broader regression script may exist:

scripts\run_sim_vivado.bat

This can run:

tb_mac_unit
tb_dot_product
tb_qk_matmul
tb_softmax_approx
tb_attention_top
tb_streaming_attention_top

But the most important one is:

tb_streaming_attention_top
Current Milestone

The current milestone is:

TB-only verification closure for FlashAttention-inspired streaming attention core.

Tasks:

Ensure Python streaming golden model exists.
Ensure streaming RTL core exists.
Ensure tb_streaming_attention_top.v compares RTL output to golden.
Ensure tolerance is documented.
Ensure PASS/FAIL is printed clearly.
Ensure no FPGA/SoC/AXI/DDR/DMA work is added.
Ensure generated artifacts are ignored.
Ensure README explains how to run the core testbench.
Next Milestone After Core TB Passes

After tb_streaming_attention_top passes, the next useful work is more verification:

test_all_zero_vectors
test_identity_like_vectors
test_random_seed_vectors
test_mixed_positive_negative_vectors
test_large_score_range_vectors
test_tile_size_1_2_4_8

Do not move to AXI, DDR, DMA, or board deployment unless explicitly requested.

Commit Rules

Keep commits focused.

Good commit messages:

Add streaming attention golden model
Add streaming attention core testbench
Fix fixed-point output comparison tolerance
Add Vivado core test runner
Document TB-only verification scope

Bad commit style:

big update
final
fix all
random changes
Agent Behavior

When asked to modify the project:

Read this file first.
Check current repository state.
Make the smallest useful change.
Prefer correctness over optimization.
Run available tests.
Report exactly what was tested.
Do not claim unrun tests passed.
Do not add hardware deployment features unless explicitly requested.
