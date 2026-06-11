# Fixed-Point Notes

## Scope and status

This document records the fixed-point formats used by the early RTL blocks. The current softmax is an approximation for simulation bring-up and does not claim exact floating-point softmax accuracy.

Verified in the current environment:

- `softmax_approx` simulation checks basic row maximum behavior, probability-sum sanity, dominant-score behavior, and simple ordering/symmetry cases.

Needs verification:

- Error tolerance against a floating-point model over broad score distributions.
- Impact of score scaling before softmax.
- Broader end-to-end attention output tolerance beyond the current one-vector smoke test.
- Synthesis, timing, power, and utilization.

## Score input format

The softmax row input is a packed row of eight signed int32 scores:

```text
score_row[(i*32) +: 32] = score[i]
```

For the current QK stage, these are unscaled `Q*K^T` scores. A later scale stage may change the numeric range before softmax.

## Exponential LUT format

`exp_lut` receives an integer difference:

```text
diff = score[i] - row_max
```

Because `row_max` is the maximum score in the row, `diff` should be less than or equal to zero. The LUT output uses unsigned Q8.8 format:

```text
1.0 -> 256
0.0 -> 0
```

The current LUT is intentionally small:

| `diff` | Approximate output | Meaning |
| --- | ---: | --- |
| `0` or positive | 256 | clipped `exp(0)` |
| `-1` | 94 | approximate `exp(-1)` |
| `-2` | 35 | approximate `exp(-2)` |
| `-3` | 13 | approximate `exp(-3)` |
| `-4` | 5 | approximate `exp(-4)` |
| `-5` | 2 | approximate `exp(-5)` |
| `-6` | 1 | approximate `exp(-6)` |
| `<= -7` | 0 | clipped tail |

This clipping is a deliberate simplification and must be revisited if later tests require better numerical fidelity.

## Row sum format

`row_sum` sums eight Q8.8 exponential values into an unsigned 20-bit value. The largest current sum is:

```text
8 * 256 = 2048
```

The 20-bit width is intentionally conservative for readability and future changes.

## Probability output format

`softmax_approx` outputs eight unsigned Q0.8 probabilities:

```text
prob_row[(i*8) +: 8] = floor(exp_i * 255 / sum_exp)
```

Interpretation:

```text
255 ~= 1.0
128 ~= 0.5
0   ~= 0.0
```

Because integer division truncates, the eight output probabilities may sum to slightly less than 255. Current tests check that the sum is reasonable, not exactly equal to 255.

## Attention output format

The first integrated `attention_top` output uses signed int32 values from `pv_matmul` that are still scaled by the Q0.8 probability factor:

```text
o_scaled[i][d] = sum(prob_q0_8[i][j] * V[j][d])
real_approx[i][d] ~= o_scaled[i][d] / 255
```

The simulation golden file `vectors/golden_output_fixed.mem` uses the same scaled integer convention.

## Accuracy statement

This implementation is a fixed-point approximation. It should be used only as a first simulation milestone until a tolerance-based comparison against the Python reference is added. Do not describe this softmax as mathematically exact.
