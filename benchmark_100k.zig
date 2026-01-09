const std = @import("std");
const disk_stabbing = @import("disk_stabbing.zig");
const DiskStabbingDS = disk_stabbing.DiskStabbingDS;
const Circle = disk_stabbing.Circle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test configurations
    const test_configs = [_]struct {
        n: usize,
        description: []const u8,
        density: f64, // Controls intersection density
    }{
        .{ .n = 1000, .description = "1K circles (warmup)", .density = 0.1 },
        .{ .n = 10000, .description = "10K circles", .density = 0.1 },
        .{ .n = 50000, .description = "50K circles", .density = 0.1 },
        .{ .n = 100000, .description = "100K circles (sparse)", .density = 0.05 },
        .{ .n = 100000, .description = "100K circles (moderate)", .density = 0.1 },
    };

    for (test_configs) |config| {
        std.debug.print("\n============================================================\n", .{});
        std.debug.print("Testing: {s}\n", .{config.description});
        std.debug.print("============================================================\n", .{});

        // Generate random circles
        var prng = std.Random.DefaultPrng.init(42);
        var rng = prng.random();

        const circles = try allocator.alloc(Circle, config.n);
        defer allocator.free(circles);

        // Distribute circles in a way that creates controlled intersection density
        const area_size: f64 = @sqrt(@as(f64, @floatFromInt(config.n)) / config.density);
        const max_radius: f64 = area_size / 50.0; // Scale radius with area

        for (circles) |*c| {
            c.cx = (rng.float(f64) - 0.5) * area_size;
            c.cy = (rng.float(f64) - 0.5) * area_size;
            c.r = rng.float(f64) * max_radius + max_radius * 0.2;
        }

        std.debug.print("Area: {d:.0} x {d:.0}\n", .{ area_size, area_size });
        std.debug.print("Avg radius: {d:.2}\n", .{max_radius * 0.7});
        std.debug.print("Expected intersections: ~{d}\n", .{@as(usize, @intFromFloat(@as(f64, @floatFromInt(config.n)) * config.density * 10))});

        // Build data structure
        var ds = try DiskStabbingDS.init(allocator, circles);
        defer ds.deinit();

        var timer = try std.time.Timer.start();

        try ds.build();

        const build_time_ns = timer.read();
        const build_time_ms = @as(f64, @floatFromInt(build_time_ns)) / 1_000_000.0;

        std.debug.print("\nBuild time: {d:.2} ms ({d:.3} s)\n", .{ build_time_ms, build_time_ms / 1000.0 });

        // Report stats
        std.debug.print("Slabs created: {d}\n", .{ds.slabs.len});

        // Calculate average active circles per slab
        var total_active: usize = 0;
        for (ds.slabs) |slab| {
            if (slab.order.len > 0) {
                total_active += slab.order.len / 2; // Each circle has 2 endpoints
            }
        }
        const avg_active = if (ds.slabs.len > 0) total_active / ds.slabs.len else 0;
        std.debug.print("Avg active circles per slab: {d}\n", .{avg_active});

        // Performance check
        if (config.n == 100000) {
            if (build_time_ms < 1000.0) {
                std.debug.print("\n✓ BUILD TIME TARGET MET: < 1 second\n", .{});
            } else {
                std.debug.print("\n✗ BUILD TIME TARGET MISSED: {d:.2} ms (target: < 1000 ms)\n", .{build_time_ms});
            }
        }

        // Test query performance
        std.debug.print("\n--- Query Performance ---\n", .{});

        const num_queries = 10000;
        var query_times = try allocator.alloc(u64, num_queries);
        defer allocator.free(query_times);

        var total_results: usize = 0;

        for (0..num_queries) |i| {
            const xq = (rng.float(f64) - 0.5) * area_size;
            const yq = (rng.float(f64) - 0.5) * area_size;

            timer.reset();
            const result = try ds.query(xq, yq, allocator);
            query_times[i] = timer.read();

            total_results += result.len;
            allocator.free(result);
        }

        // Calculate statistics
        std.mem.sort(u64, query_times, {}, std.sort.asc(u64));

        const min_ns = query_times[0];
        const max_ns = query_times[num_queries - 1];
        const median_ns = query_times[num_queries / 2];
        const p95_ns = query_times[(num_queries * 95) / 100];
        const p99_ns = query_times[(num_queries * 99) / 100];

        var sum_ns: u64 = 0;
        for (query_times) |t| sum_ns += t;
        const avg_ns = sum_ns / num_queries;

        std.debug.print("Queries: {d}\n", .{num_queries});
        std.debug.print("Avg results per query: {d}\n", .{total_results / num_queries});
        std.debug.print("\nQuery time (microseconds):\n", .{});
        std.debug.print("  Min:    {d:.2} μs\n", .{@as(f64, @floatFromInt(min_ns)) / 1000.0});
        std.debug.print("  Avg:    {d:.2} μs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1000.0});
        std.debug.print("  Median: {d:.2} μs\n", .{@as(f64, @floatFromInt(median_ns)) / 1000.0});
        std.debug.print("  P95:    {d:.2} μs\n", .{@as(f64, @floatFromInt(p95_ns)) / 1000.0});
        std.debug.print("  P99:    {d:.2} μs\n", .{@as(f64, @floatFromInt(p99_ns)) / 1000.0});
        std.debug.print("  Max:    {d:.2} μs\n", .{@as(f64, @floatFromInt(max_ns)) / 1000.0});

        // Performance check for 100k
        if (config.n == 100000) {
            const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
            if (avg_us < 1000.0) {
                std.debug.print("\n✓ QUERY TIME TARGET MET: < 1 ms average\n", .{});
            } else {
                std.debug.print("\n✗ QUERY TIME TARGET MISSED: {d:.2} μs (target: < 1000 μs)\n", .{avg_us});
            }
        }

        // Verify correctness on a sample
        std.debug.print("\n--- Correctness Check ---\n", .{});
        var correct: usize = 0;
        var total_checked: usize = 0;

        for (0..100) |_| {
            const xq = (rng.float(f64) - 0.5) * area_size;
            const yq = (rng.float(f64) - 0.5) * area_size;

            const result = try ds.query(xq, yq, allocator);
            defer allocator.free(result);

            // Brute force verification
            for (result) |i| {
                total_checked += 1;
                if (circles[i].containsPoint(xq, yq)) {
                    correct += 1;
                }
            }

            // Check for false negatives
            for (circles, 0..) |c, i| {
                if (c.containsPoint(xq, yq)) {
                    var found = false;
                    for (result) |r| {
                        if (r == i) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        std.debug.print("ERROR: False negative for circle {d} at ({d:.2}, {d:.2})\n", .{ i, xq, yq });
                    }
                }
            }
        }

        if (total_checked == correct) {
            std.debug.print("✓ All {d} results verified correct\n", .{correct});
        } else {
            std.debug.print("✗ Correctness check failed: {d}/{d} correct\n", .{ correct, total_checked });
        }
    }

    std.debug.print("\n============================================================\n", .{});
    std.debug.print("Benchmark Complete\n", .{});
    std.debug.print("============================================================\n", .{});
}
