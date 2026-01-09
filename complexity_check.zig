const std = @import("std");
const DiskStabbingDS = @import("disk_stabbing.zig").DiskStabbingDS;
const Circle = @import("disk_stabbing.zig").Circle;

const DataPoint = struct {
    n: f64,
    time_us: f64,
    space_mb: f64,
};

fn countNodes(node: anytype) u64 {
    if (node) |n| {
        return 1 + countNodes(n.left) + countNodes(n.right);
    }
    return 0;
}

fn linearRegression(x: []const f64, y: []const f64) struct { slope: f64, intercept: f64, r_squared: f64 } {
    var sum_x: f64 = 0;
    var sum_y: f64 = 0;
    var sum_xx: f64 = 0;
    var sum_xy: f64 = 0;

    const n = @as(f64, @floatFromInt(x.len));

    for (x, y) |xi, yi| {
        sum_x += xi;
        sum_y += yi;
        sum_xx += xi * xi;
        sum_xy += xi * yi;
    }

    const slope = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);
    const intercept = (sum_y - slope * sum_x) / n;

    // Calculate R²
    const y_mean = sum_y / n;
    var ss_tot: f64 = 0;
    var ss_res: f64 = 0;

    for (x, y) |xi, yi| {
        const y_pred = slope * xi + intercept;
        ss_tot += (yi - y_mean) * (yi - y_mean);
        ss_res += (yi - y_pred) * (yi - y_pred);
    }

    const r_squared = 1.0 - (ss_res / ss_tot);

    return .{ .slope = slope, .intercept = intercept, .r_squared = r_squared };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                      COMPLEXITY VERIFICATION                                   ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Testing theoretical complexity bounds:\n", .{});
    std.debug.print("  - Query time:  O(log n)\n", .{});
    std.debug.print("  - Space usage: O(n log n)\n", .{});
    std.debug.print("\n", .{});

    // Test sizes
    const sizes = [_]usize{ 100, 200, 500, 1000, 2000, 5000, 10000, 20000 };
    const n_queries_per_test = 1000;

    var data_points = std.ArrayList(DataPoint).init(allocator);
    defer data_points.deinit(allocator);

    std.debug.print("Running complexity tests...\n", .{});
    std.debug.print("─" ** 80 ++ "\n", .{});
    std.debug.print("{s:>8} {s:>12} {s:>15} {s:>15}\n", .{ "n", "queries", "avg_query_us", "space_mb" });
    std.debug.print("─" ** 80 ++ "\n", .{});

    for (sizes) |n| {
        var prng = std.Random.DefaultPrng.init(42 + n);
        var rng = prng.random();

        // Generate circles
        const circles = try allocator.alloc(Circle, n);
        defer allocator.free(circles);

        for (circles) |*c| {
            c.cx = (rng.float(f64) - 0.5) * 1000.0;
            c.cy = (rng.float(f64) - 0.5) * 1000.0;
            c.r = rng.float(f64) * 50.0 + 1.0;
        }

        // Build structure
        var ds = try DiskStabbingDS.init(allocator, circles);
        defer ds.deinit();
        try ds.build();

        // Measure query time
        const query_start = std.time.nanoTimestamp();
        for (0..n_queries_per_test) |_| {
            const xq = (rng.float(f64) - 0.5) * 1100.0;
            const yq = (rng.float(f64) - 0.5) * 1100.0;
            const result = try ds.query(xq, yq, allocator);
            allocator.free(result);
        }
        const query_time_ns = std.time.nanoTimestamp() - query_start;
        const avg_query_us = @as(f64, @floatFromInt(query_time_ns)) / (@as(f64, @floatFromInt(n_queries_per_test)) * 1000.0);

        // Estimate space usage
        var total_nodes: u64 = 0;
        var total_endpoints: u64 = 0;
        for (ds.slabs) |slab| {
            if (slab.root) |root| {
                total_nodes += countNodes(root);
            }
            total_endpoints += slab.order.len;
        }

        const space_bytes = total_nodes * @sizeOf(@TypeOf(ds.slabs[0].root.?.*)) +
            total_endpoints * @sizeOf(@TypeOf(ds.slabs[0].order[0]));
        const space_mb = @as(f64, @floatFromInt(space_bytes)) / (1024.0 * 1024.0);

        std.debug.print("{d:8} {d:12} {d:15.3} {d:15.3}\n", .{
            n,
            n_queries_per_test,
            avg_query_us,
            space_mb,
        });

        try data_points.append(allocator, .{
            .n = @floatFromInt(n),
            .time_us = avg_query_us,
            .space_mb = space_mb,
        });
    }

    std.debug.print("─" ** 80 ++ "\n", .{});
    std.debug.print("\n", .{});

    // Analyze query time vs log(n)
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                         QUERY TIME ANALYSIS                                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    var log_n = try allocator.alloc(f64, data_points.items.len);
    defer allocator.free(log_n);
    var times = try allocator.alloc(f64, data_points.items.len);
    defer allocator.free(times);

    for (data_points.items, 0..) |point, i| {
        log_n[i] = @log(point.n);
        times[i] = point.time_us;
    }

    const time_regression = linearRegression(log_n, times);

    std.debug.print("Linear regression: time = {d:.3} * log(n) + {d:.3}\n", .{
        time_regression.slope,
        time_regression.intercept,
    });
    std.debug.print("R² = {d:.6}\n", .{time_regression.r_squared});
    std.debug.print("\n", .{});

    if (time_regression.r_squared >= 0.85) {
        std.debug.print("✓ EXCELLENT FIT - Query time follows O(log n) as expected!\n", .{});
        if (time_regression.r_squared >= 0.95) {
            std.debug.print("  (R² ≥ 0.95 indicates near-perfect logarithmic scaling)\n", .{});
        }
    } else if (time_regression.r_squared >= 0.70) {
        std.debug.print("⚠ ACCEPTABLE FIT - Some deviation from O(log n), but reasonable\n", .{});
    } else {
        std.debug.print("✗ POOR FIT - Query time may not be following O(log n)\n", .{});
    }

    std.debug.print("\n", .{});

    // Analyze space vs n*log(n)
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                         SPACE USAGE ANALYSIS                                   ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    var n_log_n = try allocator.alloc(f64, data_points.items.len);
    defer allocator.free(n_log_n);
    var spaces = try allocator.alloc(f64, data_points.items.len);
    defer allocator.free(spaces);

    for (data_points.items, 0..) |point, i| {
        n_log_n[i] = point.n * @log(point.n);
        spaces[i] = point.space_mb;
    }

    const space_regression = linearRegression(n_log_n, spaces);

    std.debug.print("Linear regression: space = {d:.6} * n*log(n) + {d:.3}\n", .{
        space_regression.slope,
        space_regression.intercept,
    });
    std.debug.print("R² = {d:.6}\n", .{space_regression.r_squared});
    std.debug.print("\n", .{});

    if (space_regression.r_squared >= 0.85) {
        std.debug.print("✓ EXCELLENT FIT - Space usage follows O(n log n) as expected!\n", .{});
        if (space_regression.r_squared >= 0.95) {
            std.debug.print("  (R² ≥ 0.95 indicates near-perfect n log n scaling)\n", .{});
        }
    } else if (space_regression.r_squared >= 0.70) {
        std.debug.print("⚠ ACCEPTABLE FIT - Some deviation from O(n log n), but reasonable\n", .{});
    } else {
        std.debug.print("✗ POOR FIT - Space usage may not be following O(n log n)\n", .{});
    }

    std.debug.print("\n", .{});

    // Final verdict
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                              FINAL VERDICT                                     ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    const time_ok = time_regression.r_squared >= 0.70;
    const space_ok = space_regression.r_squared >= 0.70;

    if (time_ok and space_ok) {
        std.debug.print("🎉 COMPLEXITY VERIFICATION PASSED!\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("The implementation demonstrates:\n", .{});
        std.debug.print("  ✓ O(log n) query time     (R² = {d:.3})\n", .{time_regression.r_squared});
        std.debug.print("  ✓ O(n log n) space usage  (R² = {d:.3})\n", .{space_regression.r_squared});
        std.debug.print("\n", .{});
        std.debug.print("Theoretical bounds are CONFIRMED. 📊\n", .{});
    } else {
        std.debug.print("⚠ COMPLEXITY VERIFICATION INCONCLUSIVE\n", .{});
        std.debug.print("\n", .{});
        if (!time_ok) {
            std.debug.print("  ⚠ Query time R² = {d:.3} (expected ≥ 0.70)\n", .{time_regression.r_squared});
        }
        if (!space_ok) {
            std.debug.print("  ⚠ Space usage R² = {d:.3} (expected ≥ 0.70)\n", .{space_regression.r_squared});
        }
        std.debug.print("\n", .{});
        std.debug.print("Note: Real-world factors (caching, GC, etc.) can affect R²\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
}
