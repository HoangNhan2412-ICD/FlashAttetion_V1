#!/usr/bin/env python3
"""Fixed-point reference helpers matching the first RTL approximation.

This is not a mathematically exact softmax model. It mirrors the intentionally
small RTL LUT used for simulation bring-up.
"""

from __future__ import annotations

from typing import List, Sequence

from attention_ref import D_MODEL, SEQ_LEN, qk_scores

PROB_SCALE = 255
EXP_SCALE = 256


def exp_lut_q8_8(diff: int) -> int:
    """Approximate exp(diff) in unsigned Q8.8, matching rtl/softmax/exp_lut.v."""

    if diff >= 0:
        return 256
    table = {
        -1: 94,
        -2: 35,
        -3: 13,
        -4: 5,
        -5: 2,
        -6: 1,
    }
    return table.get(diff, 0)


def softmax_row_q0_8(scores: Sequence[int]) -> List[int]:
    """Return approximate Q0.8 probabilities for one score row."""

    if len(scores) != SEQ_LEN:
        raise ValueError(f"softmax row must have {SEQ_LEN} scores")
    row_max = max(scores)
    exp_values = [exp_lut_q8_8(score - row_max) for score in scores]
    exp_sum = sum(exp_values)
    if exp_sum == 0:
        return [0 for _ in scores]
    return [(value * PROB_SCALE) // exp_sum for value in exp_values]


def softmax_matrix_q0_8(scores: Sequence[Sequence[int]]) -> List[List[int]]:
    """Apply approximate Q0.8 softmax to every score row."""

    if len(scores) != SEQ_LEN:
        raise ValueError(f"score matrix must have {SEQ_LEN} rows")
    return [softmax_row_q0_8(row) for row in scores]


def pv_output_scaled(probabilities: Sequence[Sequence[int]], v: Sequence[Sequence[int]]) -> List[List[int]]:
    """Compute scaled fixed-point P*V output.

    The returned integer is still scaled by PROB_SCALE. Divide by 255 to
    interpret it as an approximate real-valued attention output.
    """

    if len(probabilities) != SEQ_LEN or len(v) != SEQ_LEN:
        raise ValueError(f"probabilities and v must have {SEQ_LEN} rows")
    output: List[List[int]] = []
    for prob_row in probabilities:
        if len(prob_row) != SEQ_LEN:
            raise ValueError(f"probability rows must have {SEQ_LEN} entries")
        out_row: List[int] = []
        for dim in range(D_MODEL):
            acc = 0
            for token in range(SEQ_LEN):
                acc += prob_row[token] * int(v[token][dim])
            out_row.append(acc)
        output.append(out_row)
    return output


def attention_fixed(q: Sequence[Sequence[int]], k: Sequence[Sequence[int]], v: Sequence[Sequence[int]]) -> List[List[int]]:
    """Compute the first RTL-style fixed-point attention approximation."""

    scores = qk_scores(q, k)
    probabilities = softmax_matrix_q0_8(scores)
    return pv_output_scaled(probabilities, v)
