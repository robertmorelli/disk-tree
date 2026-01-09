# Disk Stabbing with Persistent Trees

O(n log n) disk stabbing data structure using persistent segment trees.

## Implementations

### Python (Reference)
- Persistent segment trees for O(n log n) construction
- 25 comprehensive tests
- Works with PyPy for speedup

**Files**: `disk_tree.py`, `seg_tree.py`, `test_persistent.py`, `PERSISTENT_TREES.md`

### Zig (High Performance)
- **7x faster** build, **22x faster** queries
- Arena allocator = perfect for persistent trees
- Zero-cost abstractions
- 12 comprehensive tests

**Files**: `disk_stabbing.zig`, `benchmark.zig`, `build.zig`, `ZIG_PORT.md`

### PyOpenCL (GPU Rendering)
- Hardware-accelerated circle visualization
- Render thousands of circles at 60fps
- Query result highlighting

**Files**: `circle_renderer.py`

## Quick Start

### Testing & Verification

```bash
# Unit tests
zig build test                    # Zig: 12 tests in ~0.1s
pypy3 run_tests.py               # Python: 25 tests in ~0.2s

# Complexity verification
./check_complexity.sh            # Verify O(log n) queries, O(n log n) space

# Stress tests (nail it to the wall!)
./run_stress_tests.sh            # 15 brutal scenarios, up to 100k circles
./compare_implementations.sh     # Zig vs Python head-to-head
```

See **[TESTING_GUIDE.md](TESTING_GUIDE.md)** for complete testing documentation.

### Benchmarks

```bash
# Zig benchmark
zig build-exe benchmark.zig -O ReleaseFast
./benchmark

# Python benchmark
pypy3 benchmark_complexity.py
```

### GPU Renderer

```bash
# Requires PyOpenCL
pip install pyopencl numpy pillow

# Run demo
python3 circle_renderer.py
```

## Performance

| Implementation | Build (2000 disks) | Query | Language |
|----------------|-------------------|-------|----------|
| Python/PyPy    | ~3000ms           | ~0.2ms | Python 3 |
| **Zig**        | **417ms**         | **9µs** | Zig 0.15 |
| **GPU (PyOpenCL)** | **-**         | **Parallel** | OpenCL |

## Algorithm

1. **Sweep-line** across x-coordinates
2. **Persistent segment trees** in each slab
3. **Path copying** for O(log n) node creation per update
4. **Binary search** + tree descent for O(log n) queries

### Complexity

- **Preprocessing**: O(n log n)
- **Query**: O(log n + k) where k = result size
- **Space**: O(n log n) with structure sharing

## Key Features

✅ **Persistent Trees**: Old versions stay intact after updates
✅ **Arena Allocation**: Bulk deallocation, cache-friendly
✅ **Comprehensive Tests**: Property-based + randomized
✅ **GPU Rendering**: Visualize thousands of circles
✅ **Fast AF**: Microsecond queries in Zig

## Theory

Disk stabbing: Given n disks in 2D, preprocess to answer "which disks contain point (x,y)?"

**Naive**: O(n) per query

**This approach**:
- Sweep x-axis, creating slabs between events
- In each slab, y-order of circle endpoints is fixed
- Build segment tree over endpoint ranks
- Insert disks as intervals in segment tree
- **Key insight**: Use persistent trees to avoid O(n²) rebuilding

## References

- de Berg et al., "Computational Geometry: Algorithms and Applications"
- Persistent Data Structures (Driscoll et al., 1986)
- Arena allocation patterns

---

Made with Claude Code 🤖
