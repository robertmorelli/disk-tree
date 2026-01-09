#!/usr/bin/env python3
"""
Generate portable test data for cross-language benchmarking.
Creates JSON files that can be used by both Python and Zig implementations.
"""

import json
import random
from dataclasses import dataclass, asdict
from typing import List, Tuple


@dataclass
class Circle:
    cx: float
    cy: float
    r: float


@dataclass
class TestCase:
    name: str
    seed: int
    n_circles: int
    n_queries: int
    circles: List[dict]  # List of {cx, cy, r}
    queries: List[Tuple[float, float]]  # List of (x, y)


def generate_test_case(name: str, n_circles: int, n_queries: int, seed: int, range_val: float = 1000.0) -> TestCase:
    """Generate a test case with specified parameters"""
    random.seed(seed)

    # Generate circles
    circles = []
    for _ in range(n_circles):
        cx = (random.random() - 0.5) * range_val
        cy = (random.random() - 0.5) * range_val
        r = random.random() * 50.0 + 1.0
        circles.append({'cx': cx, 'cy': cy, 'r': r})

    # Generate queries
    queries = []
    for _ in range(n_queries):
        qx = (random.random() - 0.5) * range_val * 1.1
        qy = (random.random() - 0.5) * range_val * 1.1
        queries.append([qx, qy])

    return TestCase(
        name=name,
        seed=seed,
        n_circles=n_circles,
        n_queries=n_queries,
        circles=circles,
        queries=queries
    )


def main():
    print("Generating portable test data...")
    print("=" * 70)

    test_cases = [
        # Warm-up
        ("warmup", 100, 1000, 42),

        # Scale tests
        ("scale_1k", 1000, 10000, 1),
        ("scale_5k", 5000, 10000, 2),
        ("scale_10k", 10000, 10000, 3),
        ("scale_20k", 20000, 5000, 4),
        ("scale_50k_MASSIVE", 50000, 1000, 5),

        # Query-heavy
        ("query_heavy_100k", 1000, 100000, 10),
        ("query_heavy_50k", 5000, 50000, 11),
        ("query_heavy_25k", 10000, 25000, 12),

        # Dense
        ("dense_5k", 5000, 10000, 20),
        ("dense_10k_EXTREME", 10000, 5000, 21),

        # Memory stress
        ("memory_stress_30k", 30000, 1000, 30),
        ("memory_stress_100k_INSANE", 100000, 100, 31),

        # Pathological
        ("pathological_mixed", 10000, 10000, 40),
        ("pathological_20k", 20000, 5000, 41),
    ]

    all_tests = {}

    for name, n_circles, n_queries, seed in test_cases:
        print(f"Generating {name}: {n_circles} circles, {n_queries} queries...")
        test = generate_test_case(name, n_circles, n_queries, seed)
        all_tests[name] = asdict(test)

    # Save to JSON
    output_file = "test_data.json"
    print(f"\nSaving to {output_file}...")

    with open(output_file, 'w') as f:
        json.dump(all_tests, f)

    print(f"✓ Generated {len(test_cases)} test cases")

    # Print file size
    import os
    size_mb = os.path.getsize(output_file) / (1024 * 1024)
    print(f"✓ File size: {size_mb:.2f} MB")

    print("\nTest cases:")
    for name, n_circles, n_queries, seed in test_cases:
        print(f"  - {name:30} {n_circles:6} circles × {n_queries:6} queries")

    print("\n" + "=" * 70)
    print("Done! Use this data to benchmark Python vs Zig.")


if __name__ == "__main__":
    main()
