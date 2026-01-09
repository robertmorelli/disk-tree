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

fn benchmarkSize(allocator: std.mem.Allocator, n_disks: usize, seed: u64) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    var rng = prng.random();

    // Generate random circles
    const circles = try allocator.alloc(Circle, n_disks);
    defer allocator.free(circles);

    for (circles) |*c| {
        c.cx = (rng.float(f64) - 0.5) * 100.0;
        c.cy = (rng.float(f64) - 0.5) * 100.0;
        c.r = rng.float(f64) * 10.0 + 1.0;
    }

    const start = std.time.nanoTimestamp();
    var ds = try DiskStabbingDS.init(allocator, circles);
    defer ds.deinit();

    try ds.build();
    const elapsed = std.time.nanoTimestamp() - start;

    // Count nodes
    var total_nodes: u64 = 0;
    var total_endpoints: u64 = 0;
    for (ds.slabs) |slab| {
        if (slab.root) |root| {
            total_nodes += countNodes(root);
        }
        total_endpoints += slab.order.len;
    }

    const elapsed_ms = @as(f64, @floatFromInt(elapsed)) / 1_000_000.0;

    std.debug.print("{d:5}  {d:6}  {d:10}  {d:10}  {d:8.2}\n", .{
        n_disks,
        ds.slabs.len,
        total_nodes,
        total_endpoints,
        elapsed_ms,
    });

    // Run some queries
    const n_queries = 100;
    const query_start = std.time.nanoTimestamp();
    for (0..n_queries) |_| {
        const xq = (rng.float(f64) - 0.5) * 100.0;
        const yq = (rng.float(f64) - 0.5) * 100.0;
        const result = try ds.query(xq, yq, allocator);
        allocator.free(result);
    }
    const query_elapsed = std.time.nanoTimestamp() - query_start;
    const query_ms = @as(f64, @floatFromInt(query_elapsed)) / 1_000_000.0;
    const avg_query_us = query_ms * 1000.0 / @as(f64, @floatFromInt(n_queries));

    std.debug.print("       Queries: {d} in {d:.2}ms (avg {d:.2}µs)\n", .{ n_queries, query_ms, avg_query_us });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Disk Stabbing Structure Benchmark (Zig)\n", .{});
    std.debug.print("=" ** 70 ++ "\n", .{});
    std.debug.print("n     slabs  nodes      endpoints  build_ms\n", .{});
    std.debug.print("-" ** 70 ++ "\n", .{});

    const sizes = [_]usize{ 10, 20, 50, 100, 200, 500, 1000, 2000 };
    for (sizes) |n| {
        try benchmarkSize(allocator, n, 42);
    }

    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("Benchmark complete!\n", .{});
    std.debug.print("Note: Zig uses arena allocator - perfect for persistent trees!\n", .{});
}
