# Architecture

## Scope

This document describes the intended high-level architecture for the first simulation-oriented version of the FlashAttention-inspired streaming Transformer accelerator.

Current status:

- Verified: documentation structure and Python reference-model smoke checks.
- Verified: unit simulations for MAC, dot-product, QK, softmax approximation, and the first integrated attention-top pipeline in the current environment.
- Needs verification: broader numerical tolerance testing, cycle-level performance characterization, timing, utilization, and power.

## Target problem size

The initial design target is intentionally small:

| Parameter | Value |
| --- | --- |
| `SEQ_LEN` | 8 |
| `D_MODEL` | 8 |
| Input data | signed int8 `Q`, `K`, `V` |
| Dot-product accumulator | signed int32 |
| Softmax | fixed-point approximation in a later milestone |

The accelerator boundary receives `Q`, `K`, and `V` directly. Learned projection layers such as `Wq`, `Wk`, and `Wv` are out of scope for early milestones.

## Intended pipeline

```text
Q buffer
   |
   v
K buffer ---> QK^T matmul ---> softmax approximation ---> P*V matmul ---> output buffer
   |                                  ^                         ^
   v                                  |                         |
V buffer -----------------------------+-------------------------+
```

A simpler linear view is:

```text
Q buffer -> K buffer -> V buffer -> QK matmul -> softmax approximation -> PV matmul -> output buffer
```

## Block responsibilities

### Q/K/V buffers

The input buffers hold one `SEQ_LEN x D_MODEL` tile each for `Q`, `K`, and `V`. For the first milestones, these buffers can be simple memories or register arrays that favor debug visibility over area efficiency.

Status: Verified only as input registers inside `attention_top` smoke simulation; standalone buffer modules still need verification.

### QK matmul

The QK matmul block computes the score matrix:

```text
S = Q * K^T
```

For each query row `i` and key row `j`, the block computes an 8-element signed dot product. Accumulation is intended to use int32 to avoid overflow for the toy configuration.

Status: Verified by QK matmul and integrated attention-top simulations for the generated 8x8 vector set.

### Scale unit

Scaled dot-product attention divides scores by `sqrt(D_MODEL)`. The Python reference model applies this scale in floating point. The RTL scale format is not finalized in this skeleton PR.

Status: Needs verification.

### Softmax approximation

The softmax block will normalize one score row at a time. Planned sub-blocks are:

- row maximum for numerical stabilization
- exponential lookup or approximation
- row sum
- normalized probability output

This block is explicitly approximate in RTL. It must be tested against the Python reference with a documented tolerance in a later milestone.

Status: Verified by sanity simulation only. This block is an approximation and is not claimed to match floating-point softmax exactly.

### PV matmul

The PV matmul block computes:

```text
O = P * V
```

where `P` is the row-normalized attention-probability matrix from softmax.

Status: Verified as part of the first integrated attention-top smoke simulation. Output remains fixed-point scaled by the Q0.8 probability factor.

### Output buffer

The output buffer stores the computed `SEQ_LEN x D_MODEL` attention output tile. In the first integrated top this is a signed int32 register array scaled by the Q0.8 probability factor.

Status: Verified by the first attention-top smoke simulation for one generated vector set; broader tests still need verification.

### Top-level control

The first integrated `attention_top` controller follows this simulation pipeline:

```text
LOAD_QKV -> QK_RUN -> SOFTMAX_RUN -> PV_RUN -> DONE
```

The top-level interface uses `start`, `valid`, and `done` signals. It does not include AXI, DDR, or external memory controllers in this milestone.

Status: Verified by a small Icarus Verilog smoke simulation against Python-generated fixed-point golden outputs.

## Design principles

- Simulation correctness first, synthesis later.
- Plain Verilog RTL unless a later milestone has a clear need for more advanced language features.
- Small, testable modules with dedicated testbenches or documented test plans.
- No Vivado IP blocks in the first milestone.
- No synthesis, timing, power, or utilization claims without real reports.
