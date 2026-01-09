#!/usr/bin/env pypy3
"""Benchmark to demonstrate O(n log n) complexity of persistent tree approach"""

import sys
import os
import time
import random

# Import from disk_tree without matplotlib
import importlib.util
spec = importlib.util.spec_from_file_location("disk_tree_no_viz", "disk_tree.py")
try:
    # Try to import, catching matplotlib error
    from disk_tree import Circle, DiskStabbingDS
except ImportError:
    # If matplotlib missing, do manual import
    from dataclasses import dataclass
    from math import sqrt
    from bisect import bisect_right
    from typing import Optional, List, Tuple, Dict, Set
    import heapq

    exec(open('disk_tree.py').read().replace('import matplotlib.pyplot as plt', '').split('def visualize(')[0])

def count_nodes(node):
    """Count total nodes in a segment tree"""
    if node is None:
        return 0
    return 1 + count_nodes(node.left) + count_nodes(node.right)

def benchmark_structure(n_disks, seed=42):
    """Benchmark the disk stabbing structure and count node creation"""
    random.seed(seed)

    # Generate random circles
    circles = []
    for _ in range(n_disks):
        cx = random.uniform(-50, 50)
        cy = random.uniform(-50, 50)
        r = random.uniform(1.0, 10.0)
        circles.append(Circle(cx, cy, r))

    start = time.time()
    ds = DiskStabbingDS(circles)
    ds.build()
    elapsed = time.time() - start

    # Count total nodes across all slabs
    total_nodes = 0
    for slab in ds._slabs:
        if slab.root:
            total_nodes += count_nodes(slab.root)

    # Count total endpoints across all slabs
    total_endpoints = sum(len(slab.order) for slab in ds._slabs)

    return {
        'n_disks': n_disks,
        'n_slabs': len(ds._slabs),
        'total_nodes': total_nodes,
        'total_endpoints': total_endpoints,
        'time': elapsed,
    }

print("Benchmarking persistent tree disk stabbing structure")
print("=" * 70)
print(f"{'n_disks':<10} {'slabs':<10} {'nodes':<12} {'endpoints':<12} {'time(s)':<10}")
print("-" * 70)

results = []
for n in [10, 20, 50, 100, 200, 500]:
    result = benchmark_structure(n)
    results.append(result)
    print(f"{result['n_disks']:<10} {result['n_slabs']:<10} {result['total_nodes']:<12} "
          f"{result['total_endpoints']:<12} {result['time']:<10.4f}")

print("\n" + "=" * 70)
print("Analysis:")
print("=" * 70)

# Check if nodes/n ratio grows slowly (should be O(log n))
for i in range(1, len(results)):
    prev = results[i-1]
    curr = results[i]
    n_ratio = curr['n_disks'] / prev['n_disks']
    node_ratio = curr['total_nodes'] / max(1, prev['total_nodes'])
    time_ratio = curr['time'] / max(0.0001, prev['time'])

    print(f"n: {prev['n_disks']} -> {curr['n_disks']} (x{n_ratio:.2f})")
    print(f"  Nodes ratio: x{node_ratio:.2f} (should be ≈ n_ratio * log_ratio for O(n log n))")
    print(f"  Time ratio:  x{time_ratio:.2f}")
    print()

print("\nKey insight for O(n log n) complexity:")
print("-" * 70)
print("With persistent trees, each disk insertion creates O(log m) new nodes")
print("where m is the number of active endpoints in that slab.")
print("Across all O(n) slabs with O(n) insertions total, we get O(n log n) nodes.")
print("Without persistence, we'd rebuild trees from scratch -> O(n² log n).")
