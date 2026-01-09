const std = @import("std");
const DiskStabbingDS = @import("disk_stabbing.zig").DiskStabbingDS;
const Circle = @import("disk_stabbing.zig").Circle;
const SegNode = @import("disk_stabbing.zig").SegNode;

fn countNodes(node: ?*SegNode) u64 {
    if (node) |n| {
        return 1 + countNodes(n.left) + countNodes(n.right);
    }
    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("Simple Complexity Check\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});
    std.debug.print("Checking if query time ≈ O(log n) and space ≈ O(n log n)\n\n", .{});

    const sizes = [_]usize{ 1000, 2000, 4000, 8000 };

    var prev_n: f64 = 0;
    var prev_time: f64 = 0;
    var prev_space: f64 = 0;

    for (sizes, 0..) |n, i| {
        var prng = std.Random.DefaultPrng.init(42);
        var rng = prng.random();

        const circles = try allocator.alloc(Circle, n);
        defer allocator.free(circles);

        for (circles) |*c| {
            c.cx = (rng.float(f64) - 0.5) * 1000.0;
            c.cy = (rng.float(f64) - 0.5) * 1000.0;
            c.r = rng.float(f64) * 50.0 + 1.0;
        }

        var ds = try DiskStabbingDS.init(allocator, circles);
        defer ds.deinit();
        try ds.build();

        // Measure query time
        const start = std.time.nanoTimestamp();
        for (0..1000) |_| {
            const xq = (rng.float(f64) - 0.5) * 1100.0;
            const yq = (rng.float(f64) - 0.5) * 1100.0;
            const result = try ds.query(xq, yq, allocator);
            allocator.free(result);
        }
        const elapsed_us = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1000.0 / 1000.0;

        // Count nodes
        var nodes: u64 = 0;
        for (ds.slabs) |slab| {
            if (slab.root) |root| {
                nodes += countNodes(root);
            }
        }

        const n_f = @as(f64, @floatFromInt(n));
        const log_n = @log(n_f);
        const n_logn = n_f * log_n;

        std.debug.print("n={d:5}  time={d:6.1}µs  nodes={d:7}  log(n)={d:.2}  n*log(n)={d:.0}\n", .{
            n,
            elapsed_us,
            nodes,
            log_n,
            n_logn,
        });

        if (i > 0) {
            const n_ratio = n_f / prev_n;
            const time_ratio = elapsed_us / prev_time;
            const space_ratio = @as(f64, @floatFromInt(nodes)) / prev_space;

            const expected_time_ratio = @log(n_f) / @log(prev_n); // log ratio
            const expected_space_ratio = n_logn / (prev_n * @log(prev_n)); // n log n ratio

            std.debug.print("  → n grew {d:.1}x, time grew {d:.2}x (expect {d:.2}x for log), space grew {d:.2}x (expect {d:.2}x for n log n)\n", .{
                n_ratio,
                time_ratio,
                expected_time_ratio,
                space_ratio,
                expected_space_ratio,
            });

            // Simple check: ratios should be within 2x of expected
            const time_ok = @abs(time_ratio - expected_time_ratio) < expected_time_ratio;
            const space_ok = @abs(space_ratio - expected_space_ratio) < expected_space_ratio * 0.5;

            if (time_ok) {
                std.debug.print("     ✓ Time scaling looks like O(log n)\n", .{});
            } else {
                std.debug.print("     ⚠ Time scaling off from O(log n)\n", .{});
            }

            if (space_ok) {
                std.debug.print("     ✓ Space scaling looks like O(n log n)\n", .{});
            } else {
                std.debug.print("     ⚠ Space scaling off from O(n log n)\n", .{});
            }
        }
        std.debug.print("\n", .{});

        prev_n = n_f;
        prev_time = elapsed_us;
        prev_space = @floatFromInt(nodes);
    }

    std.debug.print("=" ** 60 ++ "\n", .{});
    std.debug.print("If most checks show ✓, complexities are good!\n", .{});
    std.debug.print("\n", .{});
}
