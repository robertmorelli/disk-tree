const std = @import("std");
const Circle = @import("disk_stabbing.zig").Circle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    const n = 10000;
    const circles = try allocator.alloc(Circle, n);
    defer allocator.free(circles);

    for (circles) |*c| {
        c.cx = (rng.float(f64) - 0.5) * 1000.0;
        c.cy = (rng.float(f64) - 0.5) * 1000.0;
        c.r = rng.float(f64) * 50.0 + 1.0;
    }

    var count: u64 = 0;
    var with_intersections: u64 = 0;

    for (0..n) |i| {
        for (i + 1..n) |j| {
            count += 1;
            
            const c1 = circles[i];
            const c2 = circles[j];
            const dx = c2.cx - c1.cx;
            const dy = c2.cy - c1.cy;
            const d_sq = dx * dx + dy * dy;
            const d = @sqrt(d_sq);

            if (d > 0 and d <= c1.r + c2.r and d >= @abs(c1.r - c2.r)) {
                with_intersections += 1;
            }
        }
    }

    std.debug.print("Total pairs: {}\n", .{count});
    std.debug.print("Pairs with intersections: {}\n", .{with_intersections});
    std.debug.print("Percentage: {d:.1}%\n", .{@as(f64, @floatFromInt(with_intersections)) / @as(f64, @floatFromInt(count)) * 100.0});
}
