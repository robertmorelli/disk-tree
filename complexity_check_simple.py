#!/usr/bin/env pypy3
"""Simple complexity check for Python implementation"""

import time
import math
from disk_tree import Circle, DiskStabbingDS
import random

def count_nodes(node):
    """Count nodes in segment tree"""
    if node is None:
        return 0
    return 1 + count_nodes(node.left) + count_nodes(node.right)

def main():
    print()
    print("Simple Complexity Check (Python)")
    print("=" * 60)
    print("Checking if query time ≈ O(log n) and space ≈ O(n log n)\n")

    sizes = [1000, 2000, 4000, 8000]

    prev_n = 0
    prev_time = 0
    prev_space = 0

    for i, n in enumerate(sizes):
        random.seed(42)

        circles = [
            Circle(
                (random.random() - 0.5) * 1000.0,
                (random.random() - 0.5) * 1000.0,
                random.random() * 50.0 + 1.0
            )
            for _ in range(n)
        ]

        ds = DiskStabbingDS(circles)
        ds.build()

        # Measure query time
        start = time.perf_counter()
        for _ in range(1000):
            xq = (random.random() - 0.5) * 1100.0
            yq = (random.random() - 0.5) * 1100.0
            ds.query(xq, yq)
        elapsed_us = (time.perf_counter() - start) * 1_000_000

        # Count nodes
        nodes = sum(count_nodes(slab.root) for slab in ds._slabs)

        log_n = math.log(n)
        n_logn = n * log_n

        print(f"n={n:5}  time={elapsed_us:6.1f}µs  nodes={nodes:7}  "
              f"log(n)={log_n:.2f}  n*log(n)={n_logn:.0f}")

        if i > 0:
            n_ratio = n / prev_n
            time_ratio = elapsed_us / prev_time
            space_ratio = nodes / prev_space

            expected_time = math.log(n) / math.log(prev_n)
            expected_space = n_logn / (prev_n * math.log(prev_n))

            print(f"  → n grew {n_ratio:.1f}x, time grew {time_ratio:.2f}x "
                  f"(expect {expected_time:.2f}x for log), "
                  f"space grew {space_ratio:.2f}x (expect {expected_space:.2f}x for n log n)")

            time_ok = abs(time_ratio - expected_time) < expected_time
            space_ok = abs(space_ratio - expected_space) < expected_space * 0.5

            if time_ok:
                print("     ✓ Time scaling looks like O(log n)")
            else:
                print("     ⚠ Time scaling off from O(log n)")

            if space_ok:
                print("     ✓ Space scaling looks like O(n log n)")
            else:
                print("     ⚠ Space scaling off from O(n log n)")

        print()

        prev_n = n
        prev_time = elapsed_us
        prev_space = nodes

    print("=" * 60)
    print("If most checks show ✓, complexities are good!")
    print()

if __name__ == "__main__":
    main()
