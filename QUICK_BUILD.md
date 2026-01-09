# Quick Build Reference

## TL;DR

```bash
zig build                              # Build everything (optimized)
./zig-out/bin/correctness_tests        # Verify it works
```

## Build Commands

```bash
zig build                    # Build all executables (~5s first time, ~0.15s incremental)
zig build test               # Run unit tests
zig build bench              # Run benchmarks
zig build clean              # Clean build cache
```

## Override Optimization

```bash
zig build -Doptimize=Debug          # Debug (slow, safe)
zig build -Doptimize=ReleaseSafe    # Fast with safety
zig build -Doptimize=ReleaseFast    # Fastest (default)
zig build -Doptimize=ReleaseSmall   # Smallest binary
```

## Executables (in `zig-out/bin/`)

- `correctness_tests` - Quick verification
- `stress_tests` - Large dataset testing
- `complexity_check_simple` - Algorithm analysis
- `benchmark` - Performance benchmarking
- `debug_test` - Debugging utilities

## Performance

**Build:** ~5s clean, ~0.15s incremental
**Query:** ~38µs for 1000 circles (O(log n))
**Default:** ReleaseFast optimization

## Requirements

- Zig 0.15.2+
- Run `zig version` to check
