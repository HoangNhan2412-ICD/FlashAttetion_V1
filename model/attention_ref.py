#!/usr/bin/env python3
"""Floating-point reference model for scaled dot-product attention.

The first hardware milestones use a tiny fixed shape by default:
SEQ_LEN = 8, D_MODEL = 8, and signed int8 Q/K/V input values.
This module intentionally uses only the Python standard library so it can run in
minimal environments.
"""

from __future__ import annotations

import math
from typing import Iterable, List, Sequence

SEQ_LEN = 8
D_MODEL = 8

Matrix = List[List[float]]


def _check_matrix(name: str, matrix: Sequence[Sequence[float]], rows: int, cols: int) -> None:
    if len(matrix) != rows:
        raise ValueError(f"{name} must have {rows} rows, got {len(matrix)}")
    for row_index, row in enumerate(matrix):
        if len(row) != cols:
            raise ValueError(
                f"{name}[{row_index}] must have {cols} columns, got {len(row)}"
            )


def dot_product(a: Sequence[float], b: Sequence[float]) -> float:
    """Return the dot product of two equal-length vectors."""

    if len(a) != len(b):
        raise ValueError(f"dot_product length mismatch: {len(a)} != {len(b)}")
    return sum(x * y for x, y in zip(a, b))


def qk_scores(q: Sequence[Sequence[float]], k: Sequence[Sequence[float]]) -> Matrix:
    """Compute the unscaled score matrix Q*K^T."""

    _check_matrix("q", q, SEQ_LEN, D_MODEL)
    _check_matrix("k", k, SEQ_LEN, D_MODEL)
    return [[dot_product(q_row, k_row) for k_row in k] for q_row in q]


def scale_scores(scores: Sequence[Sequence[float]], d_model: int = D_MODEL) -> Matrix:
    """Scale scores by 1/sqrt(d_model)."""

    _check_matrix("scores", scores, SEQ_LEN, SEQ_LEN)
    scale = 1.0 / math.sqrt(d_model)
    return [[value * scale for value in row] for row in scores]


def softmax_rows(scores: Sequence[Sequence[float]]) -> Matrix:
    """Apply numerically stable softmax independently to each row."""

    _check_matrix("scores", scores, SEQ_LEN, SEQ_LEN)
    probabilities: Matrix = []
    for row in scores:
        row_max = max(row)
        exp_values = [math.exp(value - row_max) for value in row]
        exp_sum = sum(exp_values)
        probabilities.append([value / exp_sum for value in exp_values])
    return probabilities


def pv_output(probabilities: Sequence[Sequence[float]], v: Sequence[Sequence[float]]) -> Matrix:
    """Compute the attention output matrix P*V."""

    _check_matrix("probabilities", probabilities, SEQ_LEN, SEQ_LEN)
    _check_matrix("v", v, SEQ_LEN, D_MODEL)
    output: Matrix = []
    for prob_row in probabilities:
        out_row = []
        for dim in range(D_MODEL):
            out_row.append(sum(prob_row[token] * v[token][dim] for token in range(SEQ_LEN)))
        output.append(out_row)
    return output


def attention(q: Sequence[Sequence[float]], k: Sequence[Sequence[float]], v: Sequence[Sequence[float]]) -> Matrix:
    """Compute floating-point scaled dot-product attention."""

    scores = qk_scores(q, k)
    scaled = scale_scores(scores)
    probabilities = softmax_rows(scaled)
    return pv_output(probabilities, v)


def flatten_row_major(matrix: Iterable[Iterable[float]]) -> List[float]:
    """Flatten a matrix in row-major order."""

    return [value for row in matrix for value in row]


def _demo_matrix(offset: int) -> List[List[int]]:
    values = []
    for row in range(SEQ_LEN):
        values.append([((row * D_MODEL + col + offset) % 17) - 8 for col in range(D_MODEL)])
    return values


def main() -> None:
    q = _demo_matrix(0)
    k = _demo_matrix(3)
    v = _demo_matrix(6)
    out = attention(q, k, v)
    print(f"Computed attention output shape: {len(out)}x{len(out[0])}")
    print("First row:", " ".join(f"{value:.6f}" for value in out[0]))


if __name__ == "__main__":
    main()
