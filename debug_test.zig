const std = @import("std");
const DiskStabbingDS = @import("disk_stabbing.zig").DiskStabbingDS;
const Circle = @import("disk_stabbing.zig").Circle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Reproduce the exact failing case from grid_queries
    var prng = std.Random.DefaultPrng.init(123);
    var rng = prng.random();

    const circles = try allocator.alloc(Circle, 15);
    defer allocator.free(circles);

    for (circles) |*c| {
        c.cx = (rng.float(f64) - 0.5) * 20.0;
        c.cy = (rng.float(f64) - 0.5) * 20.0;
        c.r = rng.float(f64) * 5.0 + 0.5;
    }

    std.debug.print("\nCircles:\n", .{});
    for (circles, 0..) |c, i| {
        std.debug.print("  [{d}] cx={d:.3}, cy={d:.3}, r={d:.3}\n", .{ i, c.cx, c.cy, c.r });
    }

    const xq: f64 = 8.5;
    const yq: f64 = 3.5;

    var ds = try DiskStabbingDS.init(allocator, circles);
    defer ds.deinit();
    try ds.build();

    std.debug.print("\nSlabs built: {d}\n", .{ds.slabs.len});

    // Find which slab contains the query point
    var slab_idx: usize = 0;
    if (xq >= ds.xs[0]) {
        var left: usize = 0;
        var right: usize = ds.xs.len;
        while (left < right) {
            const mid = (left + right) / 2;
            if (ds.xs[mid] <= xq) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        slab_idx = if (left > 0) left - 1 else 0;
    }
    if (slab_idx >= ds.slabs.len) slab_idx = ds.slabs.len - 1;

    const slab = ds.slabs[slab_idx];
    std.debug.print("Query uses slab {d}: x in [{d:.3}, {d:.3}]\n", .{ slab_idx, slab.x_left, slab.x_right });
    std.debug.print("Slab has {d} endpoints in order\n", .{slab.order.len});

    // Check which disks should be active in this slab
    const xmid = 0.5 * (slab.x_left + slab.x_right);
    std.debug.print("\nChecking which disks are active at xmid={d:.3}:\n", .{xmid});
    for (circles, 0..) |c, i| {
        const active = (c.cx - c.r) <= xmid and xmid <= (c.cx + c.r);
        if (active or i == 4 or i == 6) {
            std.debug.print("  [{d}] x range=[{d:.3}, {d:.3}] → {s}\n", .{ i, c.cx - c.r, c.cx + c.r, if (active) "ACTIVE" else "INACTIVE" });
        }
    }

    // Check endpoint ordering at different x values
    std.debug.print("\nEndpoint y-values for disks 3 and 4:\n", .{});
    const x_vals = [_]f64{ xmid, xq };
    const x_names = [_][]const u8{ "xmid", "xq" };
    for (x_vals, x_names) |x, name| {
        std.debug.print("  At {s}={d:.3}:\n", .{ name, x });
        for ([_]u32{ 3, 4 }) |disk_id| {
            const c = circles[disk_id];
            const dx = x - c.cx;
            const inside = c.r * c.r - dx * dx;
            if (inside >= 0) {
                const t = @sqrt(inside);
                const y_lo = c.cy - t;
                const y_hi = c.cy + t;
                std.debug.print("    Disk {d}: y=[{d:.3}, {d:.3}]\n", .{ disk_id, y_lo, y_hi });
            }
        }
    }

    std.debug.print("\nQuery point: ({d:.3}, {d:.3})\n\n", .{ xq, yq });

    // Brute force
    std.debug.print("Brute force check:\n", .{});
    var brute: std.ArrayList(u32) = .{};
    defer brute.deinit(allocator);

    for (circles, 0..) |c, i| {
        const dx = xq - c.cx;
        const dy = yq - c.cy;
        const dist_sq = dx * dx + dy * dy;
        const r_sq = c.r * c.r;
        const contains = dist_sq <= r_sq;

        std.debug.print("  [{d}] dist²={d:.6} vs r²={d:.6} → {s}\n", .{
            i,
            dist_sq,
            r_sq,
            if (contains) "INSIDE" else "outside",
        });

        if (contains) {
            try brute.append(allocator, @intCast(i));
        }
    }

    // DS query
    const result = try ds.query(xq, yq, allocator);
    defer allocator.free(result);

    std.debug.print("\nBrute force result: {any}\n", .{brute.items});
    std.debug.print("DS query result:    {any}\n", .{result});

    if (result.len != brute.items.len) {
        std.debug.print("\n✗ MISMATCH: DS returned {d} disks, brute force found {d}\n", .{ result.len, brute.items.len });
        std.process.exit(1);
    }

    std.debug.print("\n✓ Results match!\n", .{});
}
