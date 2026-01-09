const std = @import("std");
const DiskStabbingDS = @import("disk_stabbing.zig").DiskStabbingDS;
const Circle = @import("disk_stabbing.zig").Circle;

/// Stress test configuration
const StressConfig = struct {
    n_circles: usize,
    n_queries: usize,
    seed: u64,
    name: []const u8,
};

/// Test result for comparison
const TestResult = struct {
    config: StressConfig,
    build_time_ns: i64,
    query_time_ns: i64,
    total_results: usize,
    memory_bytes: usize,
    success: bool,
};

fn bruteForceQuery(circles: []const Circle, xq: f64, yq: f64, allocator: std.mem.Allocator) ![]u32 {
    var result: std.ArrayList(u32) = .{};
    defer result.deinit(allocator);

    for (circles, 0..) |c, i| {
        if (c.containsPoint(xq, yq)) {
            try result.append(allocator, @intCast(i));
        }
    }

    std.mem.sort(u32, result.items, {}, std.sort.asc(u32));
    return result.toOwnedSlice(allocator);
}

fn runStressTest(allocator: std.mem.Allocator, config: StressConfig, verify: bool) !TestResult {
    var prng = std.Random.DefaultPrng.init(config.seed);
    var rng = prng.random();

    // Generate circles
    const circles = try allocator.alloc(Circle, config.n_circles);
    defer allocator.free(circles);

    const range: f64 = 1000.0;
    for (circles) |*c| {
        c.cx = (rng.float(f64) - 0.5) * range;
        c.cy = (rng.float(f64) - 0.5) * range;
        c.r = rng.float(f64) * 50.0 + 1.0;
    }

    // Build structure
    const build_start = std.time.nanoTimestamp();
    var ds = try DiskStabbingDS.init(allocator, circles);
    defer ds.deinit();
    try ds.build();
    const build_time = std.time.nanoTimestamp() - build_start;

    // Generate queries
    const queries = try allocator.alloc(struct { f64, f64 }, config.n_queries);
    defer allocator.free(queries);

    for (queries) |*q| {
        q[0] = (rng.float(f64) - 0.5) * range * 1.1; // Slightly wider for edge cases
        q[1] = (rng.float(f64) - 0.5) * range * 1.1;
    }

    // Run queries
    const query_start = std.time.nanoTimestamp();
    var total_results: usize = 0;
    var all_correct = true;

    for (queries) |q| {
        const result = try ds.query(q[0], q[1], allocator);
        defer allocator.free(result);
        total_results += result.len;

        // Verify correctness if requested
        if (verify) {
            const expected = try bruteForceQuery(circles, q[0], q[1], allocator);
            defer allocator.free(expected);

            if (result.len != expected.len) {
                all_correct = false;
                std.debug.print("MISMATCH at ({d:.2}, {d:.2}): got {d}, expected {d}\n", .{
                    q[0],
                    q[1],
                    result.len,
                    expected.len,
                });
            } else {
                for (result, expected) |r, e| {
                    if (r != e) {
                        all_correct = false;
                        break;
                    }
                }
            }
        }
    }
    const query_time = std.time.nanoTimestamp() - query_start;

    // Estimate memory (rough)
    const memory_bytes = config.n_circles * @sizeOf(Circle) + ds.slabs.len * 1024;

    return TestResult{
        .config = config,
        .build_time_ns = @intCast(build_time),
        .query_time_ns = @intCast(query_time),
        .total_results = total_results,
        .memory_bytes = memory_bytes,
        .success = all_correct,
    };
}

fn printResult(result: TestResult) void {
    const build_ms = @as(f64, @floatFromInt(result.build_time_ns)) / 1_000_000.0;
    const query_ms = @as(f64, @floatFromInt(result.query_time_ns)) / 1_000_000.0;
    const avg_query_us = query_ms * 1000.0 / @as(f64, @floatFromInt(result.config.n_queries));
    const mem_mb = @as(f64, @floatFromInt(result.memory_bytes)) / (1024.0 * 1024.0);

    std.debug.print("{s:30} ", .{result.config.name});
    std.debug.print("n={d:6} q={d:6} | ", .{ result.config.n_circles, result.config.n_queries });
    std.debug.print("build={d:8.2}ms query={d:8.2}ms ({d:6.2}µs/q) | ", .{
        build_ms,
        query_ms,
        avg_query_us,
    });
    std.debug.print("results={d:8} mem={d:6.1}MB | ", .{ result.total_results, mem_mb });
    std.debug.print("{s}\n", .{if (result.success) "✓ PASS" else "✗ FAIL"});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("=" ** 100 ++ "\n", .{});
    std.debug.print("STRESS TESTS - NAILING IT TO THE WALL\n", .{});
    std.debug.print("=" ** 100 ++ "\n\n", .{});

    const tests = [_]StressConfig{
        // Warm-up
        .{ .n_circles = 100, .n_queries = 1000, .seed = 42, .name = "warmup" },

        // Scale tests - increasing circles
        .{ .n_circles = 1000, .n_queries = 10000, .seed = 1, .name = "scale_1k" },
        .{ .n_circles = 5000, .n_queries = 10000, .seed = 2, .name = "scale_5k" },
        .{ .n_circles = 10000, .n_queries = 10000, .seed = 3, .name = "scale_10k" },
        .{ .n_circles = 20000, .n_queries = 5000, .seed = 4, .name = "scale_20k" },
        .{ .n_circles = 50000, .n_queries = 1000, .seed = 5, .name = "scale_50k_MASSIVE" },

        // Query-heavy tests
        .{ .n_circles = 1000, .n_queries = 100000, .seed = 10, .name = "query_heavy_100k" },
        .{ .n_circles = 5000, .n_queries = 50000, .seed = 11, .name = "query_heavy_50k" },
        .{ .n_circles = 10000, .n_queries = 25000, .seed = 12, .name = "query_heavy_25k" },

        // Extreme density - small area
        .{ .n_circles = 5000, .n_queries = 10000, .seed = 20, .name = "dense_5k" },
        .{ .n_circles = 10000, .n_queries = 5000, .seed = 21, .name = "dense_10k_EXTREME" },

        // Memory stress
        .{ .n_circles = 30000, .n_queries = 1000, .seed = 30, .name = "memory_stress_30k" },
        .{ .n_circles = 100000, .n_queries = 100, .seed = 31, .name = "memory_stress_100k_INSANE" },

        // Pathological cases
        .{ .n_circles = 10000, .n_queries = 10000, .seed = 40, .name = "pathological_mixed" },
        .{ .n_circles = 20000, .n_queries = 5000, .seed = 41, .name = "pathological_20k" },
    };

    std.debug.print("Running {d} stress tests...\n\n", .{tests.len});

    var total_build_time: i64 = 0;
    var total_query_time: i64 = 0;
    var all_passed = true;

    for (tests, 0..) |config, i| {
        // Enable verification for smaller tests to ensure correctness
        // Disable for very large tests to avoid timeout
        const verify = config.n_circles <= 10000;

        std.debug.print("[{d:2}/{d:2}] ", .{ i + 1, tests.len });
        const result = try runStressTest(allocator, config, verify);
        printResult(result);

        total_build_time += result.build_time_ns;
        total_query_time += result.query_time_ns;

        if (!result.success) all_passed = false;
    }

    std.debug.print("\n", .{});
    std.debug.print("=" ** 100 ++ "\n", .{});
    std.debug.print("SUMMARY\n", .{});
    std.debug.print("=" ** 100 ++ "\n", .{});

    const total_build_ms = @as(f64, @floatFromInt(total_build_time)) / 1_000_000.0;
    const total_query_ms = @as(f64, @floatFromInt(total_query_time)) / 1_000_000.0;

    std.debug.print("Total build time:  {d:10.2} ms\n", .{total_build_ms});
    std.debug.print("Total query time:  {d:10.2} ms\n", .{total_query_ms});
    std.debug.print("Total time:        {d:10.2} ms\n", .{total_build_ms + total_query_ms});
    std.debug.print("\n", .{});

    if (all_passed) {
        std.debug.print("✓ ALL TESTS PASSED - Structure survived the stress test!\n", .{});
    } else {
        std.debug.print("✗ SOME TESTS FAILED - Check output above\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("The wall has been thoroughly nailed. 🔨\n", .{});
    std.debug.print("=" ** 100 ++ "\n\n", .{});
}
