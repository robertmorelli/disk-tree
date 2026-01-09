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

    const IndexedCircle = struct {
        idx: u32,
        x_left: f64,
        x_right: f64,
    };

    var indexed = try allocator.alloc(IndexedCircle, n);
    defer allocator.free(indexed);

    for (circles, 0..) |c, i| {
        indexed[i] = .{
            .idx = @intCast(i),
            .x_left = c.cx - c.r,
            .x_right = c.cx + c.r,
        };
    }

    std.mem.sort(IndexedCircle, indexed, {}, struct {
        fn lessThan(_: void, a: IndexedCircle, b: IndexedCircle) bool {
            return a.x_left < b.x_left;
        }
    }.lessThan);

    var checked: u64 = 0;
    for (0..n) |i| {
        const ci = indexed[i];
        var j = i + 1;
        while (j < n and indexed[j].x_left <= ci.x_right) : (j += 1) {
            checked += 1;
        }
    }

    const total_pairs: u64 = (n * (n - 1)) / 2;
    std.debug.print("Total pairs: {}\n", .{total_pairs});
    std.debug.print("Checked with sweep: {}\n", .{checked});
    std.debug.print("Reduction: {d:.1}%\n", .{100.0 * (1.0 - @as(f64, @floatFromInt(checked)) / @as(f64, @floatFromInt(total_pairs)))});
}
