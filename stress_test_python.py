#!/usr/bin/env pypy3
"""
Python stress test runner - uses same test data as Zig for fair comparison.
"""

import json
import time
import sys
from dataclasses import dataclass
from typing import List, Tuple

# Import without matplotlib
exec(open('disk_tree.py').read().replace('import matplotlib.pyplot as plt', '').split('def visualize(')[0])


@dataclass
class TestResult:
    name: str
    n_circles: int
    n_queries: int
    build_time_ms: float
    query_time_ms: float
    avg_query_us: float
    total_results: int
    success: bool


def run_test_case(test_data: dict, verify: bool = False) -> TestResult:
    """Run a single test case"""
    name = test_data['name']
    n_circles = test_data['n_circles']
    n_queries = test_data['n_queries']

    # Load circles
    circles = [
        Circle(c['cx'], c['cy'], c['r'])
        for c in test_data['circles']
    ]

    # Build structure
    build_start = time.perf_counter()
    ds = DiskStabbingDS(circles)
    ds.build()
    build_time = (time.perf_counter() - build_start) * 1000  # ms

    # Run queries
    queries = test_data['queries']
    query_start = time.perf_counter()
    total_results = 0
    all_correct = True

    for qx, qy in queries:
        result = ds.query(qx, qy, exact_filter=True)
        total_results += len(result)

        # Verify if requested
        if verify:
            expected = []
            for i, c in enumerate(circles):
                dx = qx - c.cx
                dy = qy - c.cy
                if dx*dx + dy*dy <= c.r*c.r:
                    expected.append(i)

            if result != expected:
                all_correct = False
                print(f"  MISMATCH at ({qx:.2f}, {qy:.2f}): got {len(result)}, expected {len(expected)}")

    query_time = (time.perf_counter() - query_start) * 1000  # ms
    avg_query_us = (query_time * 1000) / n_queries

    return TestResult(
        name=name,
        n_circles=n_circles,
        n_queries=n_queries,
        build_time_ms=build_time,
        query_time_ms=query_time,
        avg_query_us=avg_query_us,
        total_results=total_results,
        success=all_correct
    )


def print_result(idx: int, total: int, result: TestResult):
    """Print formatted result"""
    status = "✓ PASS" if result.success else "✗ FAIL"
    print(f"[{idx:2}/{total:2}] {result.name:30} "
          f"n={result.n_circles:6} q={result.n_queries:6} | "
          f"build={result.build_time_ms:8.2f}ms query={result.query_time_ms:8.2f}ms "
          f"({result.avg_query_us:6.2f}µs/q) | "
          f"results={result.total_results:8} | {status}")


def main():
    print()
    print("=" * 100)
    print("PYTHON STRESS TESTS - Loading test data...")
    print("=" * 100)
    print()

    # Load test data
    try:
        with open('test_data.json', 'r') as f:
            all_tests = json.load(f)
    except FileNotFoundError:
        print("ERROR: test_data.json not found!")
        print("Run: python3 generate_test_data.py")
        sys.exit(1)

    test_names = [
        "warmup",
        "scale_1k",
        "scale_5k",
        "scale_10k",
        "scale_20k",
        "scale_50k_MASSIVE",
        "query_heavy_100k",
        "query_heavy_50k",
        "query_heavy_25k",
        "dense_5k",
        "dense_10k_EXTREME",
        "memory_stress_30k",
        "memory_stress_100k_INSANE",
        "pathological_mixed",
        "pathological_20k",
    ]

    print(f"Running {len(test_names)} stress tests...\n")

    results = []
    all_passed = True

    for i, name in enumerate(test_names):
        if name not in all_tests:
            print(f"WARNING: Test '{name}' not found in test data")
            continue

        # Verify first few, then just benchmark
        verify = i < 5

        test_data = all_tests[name]
        result = run_test_case(test_data, verify=verify)
        print_result(i + 1, len(test_names), result)
        results.append(result)

        if not result.success:
            all_passed = False

    # Summary
    print()
    print("=" * 100)
    print("SUMMARY")
    print("=" * 100)

    total_build = sum(r.build_time_ms for r in results)
    total_query = sum(r.query_time_ms for r in results)

    print(f"Total build time:  {total_build:10.2f} ms")
    print(f"Total query time:  {total_query:10.2f} ms")
    print(f"Total time:        {total_build + total_query:10.2f} ms")
    print()

    if all_passed:
        print("✓ ALL TESTS PASSED")
    else:
        print("✗ SOME TESTS FAILED")

    print()
    print("=" * 100)
    print()


if __name__ == "__main__":
    main()
