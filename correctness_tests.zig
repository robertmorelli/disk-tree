const std = @import("std");
const DiskStabbingDS = @import("disk_stabbing.zig").DiskStabbingDS;
const Circle = @import("disk_stabbing.zig").Circle;

/// Brute force reference implementation for correctness validation
fn bruteForce(circles: []const Circle, xq: f64, yq: f64, allocator: std.mem.Allocator) ![]u32 {
    var result: std.ArrayList(u32) = .{};
    defer result.deinit(allocator);

    for (circles, 0..) |c, i| {
        const dx = xq - c.cx;
        const dy = yq - c.cy;
        if (dx * dx + dy * dy <= c.r * c.r) {
            try result.append(allocator, @intCast(i));
        }
    }

    std.mem.sort(u32, result.items, {}, std.sort.asc(u32));
    return result.toOwnedSlice(allocator);
}

fn verifyQuery(
    ds: *const DiskStabbingDS,
    circles: []const Circle,
    xq: f64,
    yq: f64,
    allocator: std.mem.Allocator,
) !bool {
    const got = try ds.query(xq, yq, allocator);
    defer allocator.free(got);

    const expected = try bruteForce(circles, xq, yq, allocator);
    defer allocator.free(expected);

    if (got.len != expected.len) {
        std.debug.print("MISMATCH at ({d:.6}, {d:.6}): got {any}, expected {any}\n", .{
            xq,
            yq,
            got,
            expected,
        });
        return false;
    }

    for (got, expected) |g, e| {
        if (g != e) {
            std.debug.print("MISMATCH at ({d:.6}, {d:.6}): got {any}, expected {any}\n", .{
                xq,
                yq,
                got,
                expected,
            });
            return false;
        }
    }

    return true;
}

fn testCase(
    allocator: std.mem.Allocator,
    name: []const u8,
    circles: []const Circle,
    queries: []const struct { f64, f64 },
) !bool {
    var ds = try DiskStabbingDS.init(allocator, circles);
    defer ds.deinit();
    try ds.build();

    for (queries) |q| {
        if (!try verifyQuery(&ds, circles, q[0], q[1], allocator)) {
            std.debug.print("✗ FAIL: {s}\n", .{name});
            return false;
        }
    }

    std.debug.print("✓ PASS: {s}\n", .{name});
    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
    std.debug.print("CORRECTNESS TESTS - Validating against brute force\n", .{});
    std.debug.print("=" ** 80 ++ "\n\n", .{});

    var passed: usize = 0;
    var total: usize = 0;

    // Test 1: Empty
    {
        total += 1;
        const circles = [_]Circle{};
        const queries = [_]struct { f64, f64 }{.{ 0.0, 0.0 }};
        if (try testCase(allocator, "empty", &circles, &queries)) passed += 1;
    }

    // Test 2: Single circle - inside
    {
        total += 1;
        const circles = [_]Circle{.{ .cx = 0.0, .cy = 0.0, .r = 2.0 }};
        const queries = [_]struct { f64, f64 }{
            .{ 0.0, 0.0 },
            .{ 1.0, 0.0 },
            .{ 0.0, 1.0 },
            .{ -1.0, -1.0 },
        };
        if (try testCase(allocator, "single_inside", &circles, &queries)) passed += 1;
    }

    // Test 3: Single circle - outside
    {
        total += 1;
        const circles = [_]Circle{.{ .cx = 0.0, .cy = 0.0, .r = 2.0 }};
        const queries = [_]struct { f64, f64 }{
            .{ 3.0, 0.0 },
            .{ 0.0, 3.0 },
            .{ 10.0, 10.0 },
        };
        if (try testCase(allocator, "single_outside", &circles, &queries)) passed += 1;
    }

    // Test 4: Two disjoint circles
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = -10.0, .cy = 0.0, .r = 1.0 },
            .{ .cx = 10.0, .cy = 0.0, .r = 1.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ -10.0, 0.0 }, // in first
            .{ 10.0, 0.0 }, // in second
            .{ 0.0, 0.0 }, // in neither
        };
        if (try testCase(allocator, "two_disjoint", &circles, &queries)) passed += 1;
    }

    // Test 5: Two overlapping circles
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
            .{ .cx = 1.0, .cy = 0.0, .r = 2.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ 0.5, 0.0 }, // in both
            .{ -1.5, 0.0 }, // in first only
            .{ 2.5, 0.0 }, // in second only
            .{ 0.0, 2.0 }, // in neither
        };
        if (try testCase(allocator, "two_overlapping", &circles, &queries)) passed += 1;
    }

    // Test 6: Nested circles
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = 0.0, .cy = 0.0, .r = 5.0 },
            .{ .cx = 0.0, .cy = 0.0, .r = 1.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ 0.5, 0.0 }, // in both
            .{ 3.0, 0.0 }, // in outer only
            .{ 6.0, 0.0 }, // in neither
        };
        if (try testCase(allocator, "nested", &circles, &queries)) passed += 1;
    }

    // Test 7: Many concentric circles
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = 0.0, .cy = 0.0, .r = 1.0 },
            .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
            .{ .cx = 0.0, .cy = 0.0, .r = 3.0 },
            .{ .cx = 0.0, .cy = 0.0, .r = 4.0 },
            .{ .cx = 0.0, .cy = 0.0, .r = 5.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ 0.0, 0.0 }, // in all
            .{ 1.5, 0.0 }, // in 4 outer
            .{ 3.5, 0.0 }, // in 2 outer
            .{ 6.0, 0.0 }, // in none
        };
        if (try testCase(allocator, "concentric", &circles, &queries)) passed += 1;
    }

    // Test 8: Negative coordinates
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = -3.0, .cy = -4.0, .r = 2.0 },
            .{ .cx = -6.0, .cy = -8.0, .r = 1.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ -3.0, -4.0 },
            .{ -6.0, -8.0 },
            .{ -5.0, -5.0 },
        };
        if (try testCase(allocator, "negative_coords", &circles, &queries)) passed += 1;
    }

    // Test 9: Extreme query points
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
            .{ .cx = 10.0, .cy = 0.0, .r = 2.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ -1000.0, 0.0 },
            .{ 1000.0, 0.0 },
            .{ 0.0, 1000.0 },
            .{ 0.0, -1000.0 },
        };
        if (try testCase(allocator, "extreme_queries", &circles, &queries)) passed += 1;
    }

    // Test 10: Line of overlapping circles
    {
        total += 1;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const temp_alloc = arena.allocator();

        const circles = try temp_alloc.alloc(Circle, 21);
        for (0..21) |i| {
            circles[i] = Circle{
                .cx = @as(f64, @floatFromInt(i)) - 10.0,
                .cy = 0.0,
                .r = 1.1,
            };
        }

        const queries = try temp_alloc.alloc(struct { f64, f64 }, 41);
        for (0..41) |i| {
            queries[i] = .{ @as(f64, @floatFromInt(i)) * 0.5 - 10.0, 0.0 };
        }

        if (try testCase(allocator, "line_of_circles", circles, queries)) passed += 1;
    }

    // Test 11: Three-way overlap zone
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = 0.0, .cy = 0.0, .r = 3.0 },
            .{ .cx = 2.0, .cy = 0.0, .r = 3.0 },
            .{ .cx = 1.0, .cy = 1.732, .r = 3.0 },
        };
        const queries = [_]struct { f64, f64 }{
            .{ 1.0, 0.6 }, // should be in all 3
            .{ 0.0, 0.0 }, // in first
            .{ 2.0, 0.0 }, // in second
            .{ 1.0, 1.732 }, // in third
        };
        if (try testCase(allocator, "three_way_overlap", &circles, &queries)) passed += 1;
    }

    // Test 12: Determinism - same circles should give same results
    {
        total += 1;
        const circles = [_]Circle{
            .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
            .{ .cx = 1.0, .cy = 0.0, .r = 2.0 },
            .{ .cx = -1.0, .cy = 0.5, .r = 1.2 },
        };

        var ds1 = try DiskStabbingDS.init(allocator, &circles);
        defer ds1.deinit();
        try ds1.build();

        var ds2 = try DiskStabbingDS.init(allocator, &circles);
        defer ds2.deinit();
        try ds2.build();

        const queries = [_]struct { f64, f64 }{
            .{ 0.0, 0.0 },
            .{ 0.5, 0.2 },
            .{ -0.5, 0.3 },
            .{ 1.5, 0.0 },
        };

        var deterministic = true;
        for (queries) |q| {
            const r1 = try ds1.query(q[0], q[1], allocator);
            defer allocator.free(r1);

            const r2 = try ds2.query(q[0], q[1], allocator);
            defer allocator.free(r2);

            if (r1.len != r2.len) {
                deterministic = false;
                break;
            }

            for (r1, r2) |v1, v2| {
                if (v1 != v2) {
                    deterministic = false;
                    break;
                }
            }
        }

        if (deterministic) {
            std.debug.print("✓ PASS: determinism\n", .{});
            passed += 1;
        } else {
            std.debug.print("✗ FAIL: determinism\n", .{});
        }
    }

    // Test 13: Random small - extensive validation
    {
        total += 1;
        var prng = std.Random.DefaultPrng.init(42);
        var rng = prng.random();

        var all_correct = true;
        for (0..10) |trial| {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const temp_alloc = arena.allocator();

            const circles = try temp_alloc.alloc(Circle, 20);
            for (circles) |*c| {
                c.cx = (rng.float(f64) - 0.5) * 100.0;
                c.cy = (rng.float(f64) - 0.5) * 100.0;
                c.r = rng.float(f64) * 10.0 + 0.5;
            }

            var ds = try DiskStabbingDS.init(allocator, circles);
            defer ds.deinit();
            try ds.build();

            for (0..100) |_| {
                const xq = (rng.float(f64) - 0.5) * 120.0;
                const yq = (rng.float(f64) - 0.5) * 120.0;

                if (!try verifyQuery(&ds, circles, xq, yq, allocator)) {
                    std.debug.print("Failed on trial {d}\n", .{trial});
                    all_correct = false;
                    break;
                }
            }

            if (!all_correct) break;
        }

        if (all_correct) {
            std.debug.print("✓ PASS: random_small_extensive\n", .{});
            passed += 1;
        } else {
            std.debug.print("✗ FAIL: random_small_extensive\n", .{});
        }
    }

    // Test 14: Grid queries - systematic coverage
    {
        total += 1;
        var prng = std.Random.DefaultPrng.init(123);
        var rng = prng.random();

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const temp_alloc = arena.allocator();

        const circles = try temp_alloc.alloc(Circle, 15);
        for (circles) |*c| {
            c.cx = (rng.float(f64) - 0.5) * 20.0;
            c.cy = (rng.float(f64) - 0.5) * 20.0;
            c.r = rng.float(f64) * 5.0 + 0.5;
        }

        var ds = try DiskStabbingDS.init(allocator, circles);
        defer ds.deinit();
        try ds.build();

        var all_correct = true;
        var xi: i32 = -20;
        while (xi <= 20) : (xi += 1) {
            var yi: i32 = -20;
            while (yi <= 20) : (yi += 1) {
                const xq = @as(f64, @floatFromInt(xi)) * 0.5;
                const yq = @as(f64, @floatFromInt(yi)) * 0.5;

                if (!try verifyQuery(&ds, circles, xq, yq, allocator)) {
                    all_correct = false;
                    break;
                }
            }
            if (!all_correct) break;
        }

        if (all_correct) {
            std.debug.print("✓ PASS: grid_queries\n", .{});
            passed += 1;
        } else {
            std.debug.print("✗ FAIL: grid_queries\n", .{});
        }
    }

    // Summary
    std.debug.print("\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
    std.debug.print("CORRECTNESS SUMMARY: {d}/{d} tests passed\n", .{ passed, total });
    std.debug.print("=" ** 80 ++ "\n\n", .{});

    if (passed == total) {
        std.debug.print("✓ ALL CORRECTNESS TESTS PASSED!\n\n", .{});
        std.process.exit(0);
    } else {
        std.debug.print("✗ SOME CORRECTNESS TESTS FAILED!\n\n", .{});
        std.process.exit(1);
    }
}
