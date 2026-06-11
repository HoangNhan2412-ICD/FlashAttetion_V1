# FlashAttention-Inspired Streaming Transformer Accelerator on FPGA

This repository is for a small, simulation-first FPGA accelerator for the self-attention part of a Transformer. The design is inspired by the streaming and tiling ideas behind FlashAttention, but the first milestones prioritize simple, debuggable RTL and reproducible reference vectors over performance optimization.

## Project goals

- Build a Verilog RTL self-attention accelerator that can be simulated and checked against a Python reference model.
- Start with a fixed toy configuration:
  - `SEQ_LEN = 8`
  - `D_MODEL = 8`
  - `Q`, `K`, and `V` inputs are signed int8 values
  - dot-product accumulators use int32 values
  - softmax uses an initial fixed-point approximation
- Accept `Q`, `K`, and `V` directly at the accelerator boundary for early milestones.
- Defer full Transformer integration and learned `Wq`, `Wk`, `Wv` projections until after the attention datapath is verified.

## Current repository status

The repository currently includes:

- Directory layout for RTL, simulation, models, scripts, documentation, and vectors.
- Initial documentation for architecture, dataflow, and verification planning.
- A Python floating-point reference model for scaled dot-product attention.
- A deterministic vector generator for `Q`, `K`, `V`, golden QK scores, floating-point attention outputs, and fixed-point RTL-approximation outputs.
- Initial RTL blocks through the first integrated attention pipeline: QK, softmax approximation, and PV.
- Ignore rules for Python artifacts, simulation outputs, and Vivado build products.

The current integrated top is simulation-only and does not include AXI, DDR, Vivado IP, or full Transformer projection layers. No synthesis, timing, power, or resource-utilization number is claimed without real reports.

## Planned pipeline

```text
Q buffer -> K buffer -> V buffer -> QK^T matmul -> softmax approximation -> P*V matmul -> output buffer
```

Where:

- `QK^T` computes attention scores.
- softmax normalizes each score row into attention probabilities.
- `P*V` computes the attention output vectors.

## Repository layout

```text
rtl/       Verilog RTL modules, organized by datapath area
sim/       Testbenches and simulation-only files
model/     Python reference model and vector-generation utilities
vectors/   Generated input and golden-output memory files
docs/      Architecture, dataflow, verification, fixed-point, and report notes
scripts/   Simulation and synthesis helper scripts
reports/   Generated reports; build products are ignored unless explicitly curated
```

## Verification status

- Python reference model: smoke-tested in the current environment.
- Generated vectors: smoke-tested in the current environment.
- RTL simulation: MAC, dot-product, QK, softmax approximation, and full attention-top smoke simulations have passed in the current environment.
- Vivado synthesis, timing, power, and utilization: Needs verification; no synthesis flow is claimed in this PR.


## Current RTL status

The first integrated simulation pipeline is:

```text
LOAD_QKV -> QK_RUN -> SOFTMAX_RUN -> PV_RUN -> DONE
```

`attention_top` accepts packed 8x8 signed int8 `Q`, `K`, and `V` matrices and emits a packed 8x8 signed int32 output matrix. The output is fixed-point scaled by the Q0.8 probability factor (`255 ~= 1.0`). This milestone intentionally does not implement AXI, DDR, or external memory traffic.
