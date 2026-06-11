# Dataflow

## Scope and status

This document describes the intended mathematical and data-movement flow for the first attention accelerator milestones.

- Verified: the Python reference implements this mathematical flow for the toy configuration.
- Verified: the current `qk_matmul` RTL computes unscaled `Q*K^T` scores for the generated 8x8 vector set in simulation.
- Needs verification: scale, softmax, PV matmul, full RTL scheduling, streaming interfaces, fixed-point formats, and hardware tolerances.

## Input tensors

The top-level attention datapath will consume three matrices:

```text
Q: SEQ_LEN x D_MODEL signed int8
K: SEQ_LEN x D_MODEL signed int8
V: SEQ_LEN x D_MODEL signed int8
```

For the initial configuration:

```text
SEQ_LEN = 8
D_MODEL = 8
```

## Step 1: score matrix `QK^T`

Each attention score is a dot product between one query row and one key row:

```text
S[i][j] = sum(Q[i][d] * K[j][d]) for d = 0..D_MODEL-1
```

The result is an `SEQ_LEN x SEQ_LEN` score matrix. The current `qk_matmul` block produces this unscaled score matrix as signed int32 values for the 8x8 tile.

## Step 2: scale

Scaled dot-product attention applies:

```text
S_scaled[i][j] = S[i][j] / sqrt(D_MODEL)
```

The Python reference uses floating-point scaling. The RTL fixed-point scaling strategy is not finalized in this PR.

## Step 3: row-wise softmax

Softmax is applied independently to each row:

```text
P[i][j] = exp(S_scaled[i][j]) / sum(exp(S_scaled[i][k])) for k = 0..SEQ_LEN-1
```

The Python reference subtracts the row maximum before exponentiation for numerical stability. The RTL implementation will use a fixed-point approximation and must document its tolerance later.

## Step 4: weighted value accumulation `PV`

The attention output is computed as:

```text
O[i][d] = sum(P[i][j] * V[j][d]) for j = 0..SEQ_LEN-1
```

This produces an `SEQ_LEN x D_MODEL` output matrix.

## Initial vector-file convention

The vector generator writes memory files in row-major order:

```text
vectors/q_input.mem
vectors/k_input.mem
vectors/v_input.mem
vectors/golden_score.mem
vectors/golden_output_fixed.mem
vectors/golden_output.mem
```

`q_input.mem`, `k_input.mem`, and `v_input.mem` contain signed decimal int8 values, one value per line. `golden_score.mem` contains signed decimal int32 unscaled `Q*K^T` scores, one value per line in row-major order. `golden_output_fixed.mem` contains signed decimal int32 outputs from the current RTL-style fixed-point approximation, still scaled by 255. `golden_output.mem` contains floating-point reference attention output values, one value per line.

## Streaming plan

The first complete RTL can use simple buffered tiles for debug clarity. Later milestones may stream rows through the pipeline to reduce intermediate storage, but any streaming schedule must preserve the same mathematical result within the documented fixed-point tolerance.
