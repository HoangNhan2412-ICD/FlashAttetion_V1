#!/usr/bin/env python3
"""Generate deterministic Q/K/V inputs plus golden score and attention outputs."""

from __future__ import annotations

import argparse
import random
from pathlib import Path
from typing import Iterable, List

from attention_ref import D_MODEL, SEQ_LEN, attention, flatten_row_major, qk_scores
from fixed_point_ref import attention_fixed

DEFAULT_SEED = 42
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parents[1] / "vectors"


def generate_int8_matrix(rng: random.Random, rows: int = SEQ_LEN, cols: int = D_MODEL) -> List[List[int]]:
    """Generate a rows x cols matrix with deterministic signed int8 values."""

    return [[rng.randint(-8, 7) for _ in range(cols)] for _ in range(rows)]


def write_values(path: Path, values: Iterable[object]) -> None:
    """Write one value per line."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file_obj:
        for value in values:
            file_obj.write(f"{value}\n")


def write_float_values(path: Path, values: Iterable[float]) -> None:
    """Write floating-point values with stable formatting."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file_obj:
        for value in values:
            file_obj.write(f"{value:.8f}\n")


def generate_vectors(output_dir: Path, seed: int = DEFAULT_SEED) -> None:
    """Generate Q/K/V memories, unscaled QK scores, and attention outputs."""

    rng = random.Random(seed)
    q = generate_int8_matrix(rng)
    k = generate_int8_matrix(rng)
    v = generate_int8_matrix(rng)
    golden_scores = qk_scores(q, k)
    golden = attention(q, k, v)
    golden_fixed = attention_fixed(q, k, v)

    write_values(output_dir / "q_input.mem", flatten_row_major(q))
    write_values(output_dir / "k_input.mem", flatten_row_major(k))
    write_values(output_dir / "v_input.mem", flatten_row_major(v))
    write_values(output_dir / "golden_score.mem", flatten_row_major(golden_scores))
    write_values(output_dir / "golden_output_fixed.mem", flatten_row_major(golden_fixed))
    write_float_values(output_dir / "golden_output.mem", flatten_row_major(golden))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory for generated .mem files. Defaults to repo vectors/.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help="Deterministic random seed.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generate_vectors(args.output_dir, args.seed)
    print(f"Generated vectors in {args.output_dir}")
    print(f"Shape: SEQ_LEN={SEQ_LEN}, D_MODEL={D_MODEL}, seed={args.seed}")


if __name__ == "__main__":
    main()
