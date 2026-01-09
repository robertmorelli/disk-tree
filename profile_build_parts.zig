const std = @import("std");
const DiskStabbingDS = @import("disk_stabbing.zig").DiskStabbingDS;
const Circle = @import("disk_stabbing.zig").Circle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const n = 2000;
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
    
    const start = std.time.nanoTimestamp();
    try ds.build();
    const total_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    std.debug.print("Total build time: {d:.1} ms\n", .{total_ms});
    std.debug.print("Number of slabs: {}\n", .{ds.slabs.len});
}
