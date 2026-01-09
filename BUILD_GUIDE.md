# Build Guide - Optimized for Large Queries

This guide shows you how to build the Zig disk tree implementation with optimizations for handling large queries efficiently.

## Quick Start

```bash
# Build all executables with optimizations (takes ~5 seconds first time)
zig build

# Incremental rebuilds are fast (~0.15 seconds)
zig build
```

## Build Configuration

The build system is configured for **maximum performance** with large queries:

### Optimization Mode: ReleaseFast

The `build.zig` defaults to `ReleaseFast` which:
- **Optimizes for runtime speed** over binary size
- Disables safety checks for maximum performance
- Essential for handling large disk/query datasets

### Build Targets

All executables are built with the same optimization level:

```bash
zig build                           # Build all targets
zig build test                      # Run unit tests
zig build bench                     # Run benchmarks
```

### Available Executables

After building, find executables in `zig-out/bin/`:

- `benchmark` - Performance benchmarking
- `stress_tests` - Stress testing with large datasets
- `correctness_tests` - Correctness verification
- `complexity_check_simple` - Algorithm complexity verification
- `debug_test` - Debugging utilities

## Performance Characteristics

With ReleaseFast optimization:

- **Build time (first)**: ~5 seconds
- **Build time (incremental)**: ~0.15 seconds
- **Query time**: O(log n) per query
- **Build space**: O(n log n)
- **Binary size**: ~1.5MB per executable

## Override Optimization Mode

You can override the optimization mode:

```bash
# Debug mode (slower, with safety checks)
zig build -Doptimize=Debug

# Release with safety checks
zig build -Doptimize=ReleaseSafe

# Smallest binary size
zig build -Doptimize=ReleaseSmall

# Maximum speed (default)
zig build -Doptimize=ReleaseFast
```

## Testing Large Queries

```bash
# Run correctness tests (fast)
./zig-out/bin/correctness_tests

# Run stress tests with large datasets (slow)
./zig-out/bin/stress_tests

# Check algorithmic complexity
./zig-out/bin/complexity_check_simple
```

## Build System Updates (Zig 0.15.2)

The build system has been updated for Zig 0.15.2 API changes:

- Uses `addLibrary()` instead of deprecated `addStaticLibrary()`
- Uses `b.createModule()` with `root_module` parameter
- All source files specified with `b.path()`

## Troubleshooting

**Build fails with API errors?**
- Ensure you're using Zig 0.15.2 or later
- Run `zig version` to check

**Slow query performance?**
- Verify you're using ReleaseFast: `zig build -Doptimize=ReleaseFast`
- Check binary was rebuilt: `ls -lh zig-out/bin/`

**Out of memory during build?**
- For very large datasets, the build phase allocates O(n log n) space
- This is expected for the persistent segment tree structure
- Consider building with smaller test datasets first
