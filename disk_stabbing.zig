const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const treap_mod = @import("treap.zig");
const Treap = treap_mod.Treap;

/// Circle primitive
pub const Circle = struct {
    cx: f64,
    cy: f64,
    r: f64,

    pub fn containsPoint(self: Circle, x: f64, y: f64) bool {
        const dx = x - self.cx;
        const dy = y - self.cy;
        return dx * dx + dy * dy <= self.r * self.r;
    }

    pub fn yIntervalAtX(self: Circle, x: f64) ?struct { f64, f64 } {
        const dx = x - self.cx;
        const inside = self.r * self.r - dx * dx;
        if (inside < 0.0) return null;
        const t = @sqrt(inside);
        return .{ self.cy - t, self.cy + t };
    }

    /// Compute x-coordinates of circle-circle intersections
    pub fn intersectionsX(c1: Circle, c2: Circle, allocator: Allocator) ![]f64 {
        const dx = c2.cx - c1.cx;
        const dy = c2.cy - c1.cy;
        const d_sq = dx * dx + dy * dy;
        const d = @sqrt(d_sq);

        // No intersection or one inside the other
        if (d == 0.0 or d > c1.r + c2.r or d < @abs(c1.r - c2.r)) {
            return &[_]f64{};
        }

        // Compute intersection points
        const a = (c1.r * c1.r - c2.r * c2.r + d_sq) / (2.0 * d);
        const h_sq = c1.r * c1.r - a * a;
        if (h_sq <= 0.0) return &[_]f64{}; // Tangent, ignore

        const h = @sqrt(h_sq);
        const xm = c1.cx + a * dx / d;
        const rx = -dy * (h / d);

        // Two intersection x-coordinates
        const result = try allocator.alloc(f64, 2);
        result[0] = xm + rx;
        result[1] = xm - rx;
        return result;
    }
};

/// Endpoint descriptor - portable function description
pub const EndpointDesc = struct {
    circle_id: u32,
    sign: i8, // -1 for lower, +1 for upper

    pub fn eval(self: EndpointDesc, circles: []const Circle, x: f64) f64 {
        const c = circles[self.circle_id];
        const dx = x - c.cx;
        var inside = c.r * c.r - dx * dx;
        if (inside < 0.0) inside = 0.0;
        const t = @sqrt(inside);
        return c.cy + @as(f64, @floatFromInt(self.sign)) * t;
    }

    pub fn lessThan(ctx: EvalContext, a: EndpointDesc, b: EndpointDesc) bool {
        const va = a.eval(ctx.circles, ctx.x);
        const vb = b.eval(ctx.circles, ctx.x);
        return va < vb;
    }
};

pub const EvalContext = struct {
    circles: []const Circle,
    x: f64,
};

/// Persistent segment tree node
pub const SegNode = struct {
    lo: u32,
    hi: u32,
    split: ?EndpointDesc,
    left: ?*SegNode,
    right: ?*SegNode,
    bucket: []const u32, // immutable slice

    /// Build empty segment tree structure over ranks
    pub fn build(
        arena: Allocator,
        order: []const EndpointDesc,
        lo: u32,
        hi: u32,
    ) !*SegNode {
        const node = try arena.create(SegNode);
        if (lo == hi) {
            node.* = SegNode{
                .lo = lo,
                .hi = hi,
                .split = order[lo],
                .left = null,
                .right = null,
                .bucket = &[_]u32{},
            };
            return node;
        }

        const mid = (lo + hi) / 2;
        const left = try build(arena, order, lo, mid);
        const right = try build(arena, order, mid + 1, hi);

        node.* = SegNode{
            .lo = lo,
            .hi = hi,
            .split = order[mid],
            .left = left,
            .right = right,
            .bucket = &[_]u32{},
        };
        return node;
    }

    /// Mutable insert - modifies tree in place (much faster for batch construction)
    pub fn insertIntervalMut(
        self: *SegNode,
        arena: Allocator,
        ql: u32,
        qr: u32,
        disk_id: u32,
    ) !void {
        if (ql <= self.lo and self.hi <= qr) {
            // Fully covered - add to bucket
            const new_bucket = try arena.alloc(u32, self.bucket.len + 1);
            @memcpy(new_bucket[0..self.bucket.len], self.bucket);
            new_bucket[self.bucket.len] = disk_id;
            self.bucket = new_bucket;
            return;
        }

        const mid = (self.lo + self.hi) / 2;

        if (ql <= mid and self.left != null) {
            try self.left.?.insertIntervalMut(arena, ql, qr, disk_id);
        }
        if (qr > mid and self.right != null) {
            try self.right.?.insertIntervalMut(arena, ql, qr, disk_id);
        }
    }

    /// Persistent insert - returns NEW node with disk_id added
    pub fn insertInterval(
        self: *const SegNode,
        arena: Allocator,
        ql: u32,
        qr: u32,
        disk_id: u32,
    ) !*SegNode {
        const node = try arena.create(SegNode);

        if (ql <= self.lo and self.hi <= qr) {
            // Fully covered - add to bucket
            const new_bucket = try arena.alloc(u32, self.bucket.len + 1);
            @memcpy(new_bucket[0..self.bucket.len], self.bucket);
            new_bucket[self.bucket.len] = disk_id;

            node.* = SegNode{
                .lo = self.lo,
                .hi = self.hi,
                .split = self.split,
                .left = self.left,
                .right = self.right,
                .bucket = new_bucket,
            };
            return node;
        }

        const mid = (self.lo + self.hi) / 2;
        var new_left = self.left;
        var new_right = self.right;

        if (ql <= mid and self.left != null) {
            new_left = try self.left.?.insertInterval(arena, ql, qr, disk_id);
        }
        if (qr > mid and self.right != null) {
            new_right = try self.right.?.insertInterval(arena, ql, qr, disk_id);
        }

        node.* = SegNode{
            .lo = self.lo,
            .hi = self.hi,
            .split = self.split,
            .left = new_left,
            .right = new_right,
            .bucket = self.bucket, // unchanged
        };
        return node;
    }

    /// Query for disks at point (xq, yq)
    pub fn query(
        self: *const SegNode,
        circles: []const Circle,
        xq: f64,
        yq: f64,
        result: *ArrayList(u32),
        allocator: Allocator,
    ) !void {
        var cur: ?*const SegNode = self;
        while (cur) |node| {
            // Add all disks in this node's bucket
            try result.appendSlice(allocator, node.bucket);

            // Check if we're at a leaf
            if (node.left == null and node.right == null) break;

            // Evaluate split and descend
            if (node.split) |split| {
                const v = split.eval(circles, xq);
                cur = if (yq <= v) node.left else node.right;
            } else {
                break;
            }
        }
    }
};

/// Slab in sweep-line structure
pub const Slab = struct {
    x_left: f64,
    x_right: f64,
    order: []const EndpointDesc,
    root: ?*SegNode,
};

/// Main disk stabbing data structure
pub const DiskStabbingDS = struct {
    arena: ArenaAllocator,
    circles: []const Circle,
    slabs: []Slab,
    xs: []f64,

    const Event = struct {
        x: f64,
        etype: u8, // 0=start, 1=end, 2=intersection
        data: u32,

        fn lessThan(_: void, a: Event, b: Event) bool {
            if (a.x != b.x) return a.x < b.x;
            return a.etype < b.etype;
        }
    };

    pub fn init(allocator: Allocator, circles: []const Circle) !DiskStabbingDS {
        var arena = ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const ds = DiskStabbingDS{
            .arena = arena,
            .circles = circles,
            .slabs = &[_]Slab{},
            .xs = &[_]f64{},
        };

        return ds;
    }

    pub fn deinit(self: *DiskStabbingDS) void {
        self.arena.deinit();
    }

    pub fn build(self: *DiskStabbingDS) !void {
        const allocator = self.arena.allocator();
        const n = self.circles.len;
        if (n == 0) return;

        // Pre-allocate events with capacity for circles + estimated intersections
        const estimated_intersections = @min(n * 10, n * n / 100); // Estimate ~10 intersections per circle
        var events = try ArrayList(Event).initCapacity(allocator, n * 2 + estimated_intersections * 2);
        defer events.deinit(allocator);

        const START: u8 = 0;
        const END: u8 = 1;
        const XING: u8 = 2;

        // Optimized sweep line using TREAP for O(log n) active circle management
        if (n > 1) {
            // Pre-sort circles by x-coordinate for efficient sweep
            const SortByX = struct {
                circles: []const Circle,

                pub fn lessThan(ctx: @This(), a: u32, b: u32) bool {
                    return ctx.circles[a].cx < ctx.circles[b].cx;
                }
            };

            // Create index array for indirect sorting
            const indices = try allocator.alloc(u32, n);
            defer allocator.free(indices);
            for (0..n) |i| {
                indices[i] = @intCast(i);
            }
            std.mem.sort(u32, indices, SortByX{ .circles = self.circles }, SortByX.lessThan);

            // Use treap for O(log n) insert/remove/neighbor operations
            // Key is y-coordinate with small epsilon based on circle ID for uniqueness
            var active = Treap(f64, u32).init(allocator, 12345);
            defer active.deinit();

            // Map from circle ID to its y-key in the treap (for removal)
            var circle_y_keys = std.AutoHashMap(u32, f64).init(allocator);
            defer circle_y_keys.deinit();
            try circle_y_keys.ensureTotalCapacity(@intCast(n));

            // Track processed pairs using a more compact representation
            var checked_pairs = std.AutoHashMap(u64, void).init(allocator);
            defer checked_pairs.deinit();
            try checked_pairs.ensureTotalCapacity(@intCast(@min(n * 20, 100000))); // Pre-allocate

            // Helper to check intersection between two circles
            const checkIntersection = struct {
                fn call(
                    id1: u32,
                    id2: u32,
                    circles: []const Circle,
                    event_list: *ArrayList(Event),
                    pairs: *std.AutoHashMap(u64, void),
                    alloc: Allocator,
                    xing_type: u8,
                ) !void {
                    const pair_key = if (id1 < id2)
                        (@as(u64, id1) << 32) | @as(u64, id2)
                    else
                        (@as(u64, id2) << 32) | @as(u64, id1);

                    if (pairs.contains(pair_key)) return;
                    try pairs.put(pair_key, {});

                    // Inline intersection computation
                    const c1 = circles[id1];
                    const c2 = circles[id2];
                    const dx = c2.cx - c1.cx;
                    const dy = c2.cy - c1.cy;
                    const d_sq = dx * dx + dy * dy;
                    const d = @sqrt(d_sq);
                    const sum_r = c1.r + c2.r;
                    const diff_r = @abs(c1.r - c2.r);

                    if (d > 0.0 and d <= sum_r and d >= diff_r) {
                        const a = (c1.r * c1.r - c2.r * c2.r + d_sq) / (2.0 * d);
                        const h_sq = c1.r * c1.r - a * a;
                        if (h_sq > 1e-10) {
                            const h = @sqrt(h_sq);
                            const xm = c1.cx + a * dx / d;
                            const rx = -dy * (h / d);

                            try event_list.append(alloc, .{ .x = xm + rx, .etype = xing_type, .data = id1 });
                            try event_list.append(alloc, .{ .x = xm - rx, .etype = xing_type, .data = id1 });
                        }
                    }
                }
            }.call;

            // Process circles in left-to-right order
            // Also track active circles for removal
            var active_list = try ArrayList(u32).initCapacity(allocator, 100);
            defer active_list.deinit(allocator);

            for (indices) |i| {
                const c1 = self.circles[i];
                const x_left = c1.cx - c1.r;
                const x_right = c1.cx + c1.r;

                // Remove circles that have exited (x_right < x_left of current circle)
                // Use swap-remove for O(1) removal from list
                var j: usize = 0;
                while (j < active_list.items.len) {
                    const active_id = active_list.items[j];
                    if (self.circles[active_id].cx + self.circles[active_id].r < x_left) {
                        // Remove from treap (O(log n))
                        if (circle_y_keys.get(active_id)) |y_key| {
                            active.remove(y_key);
                            _ = circle_y_keys.remove(active_id);
                        }
                        // Swap with last and pop (O(1))
                        _ = active_list.swapRemove(j);
                        // Don't increment j since we just moved a new element to position j
                    } else {
                        j += 1;
                    }
                }

                // Create unique key: y + tiny epsilon based on circle ID
                const epsilon = @as(f64, @floatFromInt(i)) * 1e-9;
                const y_key = c1.cy + epsilon;

                // Check active circles that might intersect
                // Filter by both x and y distance to avoid unnecessary intersection computations
                for (active_list.items) |other_id| {
                    const c2 = self.circles[other_id];

                    // Quick rejection: check if circles are too far apart in x or y
                    const x_dist = @abs(c1.cx - c2.cx);
                    const y_dist = @abs(c1.cy - c2.cy);
                    const sum_r = c1.r + c2.r;

                    // Both x and y distances must be <= sum of radii for circles to possibly intersect
                    if (x_dist <= sum_r and y_dist <= sum_r) {
                        try checkIntersection(i, other_id, self.circles, &events, &checked_pairs, allocator, XING);
                    }
                }

                // Insert this circle into active set
                try active.insert(y_key, i);
                try circle_y_keys.put(i, y_key);
                try active_list.append(allocator, i);

                // Add circle start/end events
                try events.append(allocator, .{ .x = x_left, .etype = START, .data = i });
                try events.append(allocator, .{ .x = x_right, .etype = END, .data = i });
            }
        } else {
            // Single circle case
            for (self.circles, 0..) |c, i| {
                try events.append(allocator, .{ .x = c.cx - c.r, .etype = START, .data = @intCast(i) });
                try events.append(allocator, .{ .x = c.cx + c.r, .etype = END, .data = @intCast(i) });
            }
        }

        // Sort all events once
        std.mem.sort(Event, events.items, {}, Event.lessThan);

        // Collect unique x boundaries
        var x_boundaries: ArrayList(f64) = .{};
        defer x_boundaries.deinit(allocator);

        if (events.items.len > 0) {
            try x_boundaries.ensureTotalCapacity(allocator, @intCast(events.items.len));
            x_boundaries.appendAssumeCapacity(events.items[0].x);
            for (events.items) |event| {
                if (event.x != x_boundaries.items[x_boundaries.items.len - 1]) {
                    x_boundaries.appendAssumeCapacity(event.x);
                }
            }
        }

        // Build slabs
        const estimated_slabs = if (x_boundaries.items.len > 0) x_boundaries.items.len - 1 else 0;
        var slabs = try ArrayList(Slab).initCapacity(allocator, estimated_slabs);
        defer slabs.deinit(allocator);

        var xs = try ArrayList(f64).initCapacity(allocator, estimated_slabs);
        defer xs.deinit(allocator);

        // Maintain active set incrementally using sweep line
        var active_set = std.AutoHashMap(u32, void).init(allocator);
        defer active_set.deinit();
        try active_set.ensureTotalCapacity(@intCast(@min(n, 10000)));

        var event_idx: usize = 0;

        // Reusable buffers to avoid repeated allocations
        var active_buffer = try ArrayList(u32).initCapacity(allocator, n);
        defer active_buffer.deinit(allocator);

        var endpoints_buffer = try ArrayList(struct { f64, EndpointDesc }).initCapacity(allocator, n * 2);
        defer endpoints_buffer.deinit(allocator);

        var k: usize = 0;
        while (k + 1 < x_boundaries.items.len) : (k += 1) {
            const xl = x_boundaries.items[k];
            const xr = x_boundaries.items[k + 1];
            if (xr <= xl) continue;

            const xmid = 0.5 * (xl + xr);

            // Process all events up to and including xmid to update active set
            while (event_idx < events.items.len and events.items[event_idx].x <= xmid) : (event_idx += 1) {
                const ev = events.items[event_idx];
                if (ev.etype == START) {
                    try active_set.put(ev.data, {});
                } else if (ev.etype == END) {
                    _ = active_set.remove(ev.data);
                }
                // XING events don't affect active set
            }

            // Reuse buffer for active circles
            active_buffer.clearRetainingCapacity();
            var it = active_set.keyIterator();
            while (it.next()) |key| {
                active_buffer.appendAssumeCapacity(key.*);
            }

            if (active_buffer.items.len == 0) {
                xs.appendAssumeCapacity(xl);
                slabs.appendAssumeCapacity(Slab{
                    .x_left = xl,
                    .x_right = xr,
                    .order = &[_]EndpointDesc{},
                    .root = null,
                });
                continue;
            }

            // Build endpoint order using reusable buffer
            endpoints_buffer.clearRetainingCapacity();
            for (active_buffer.items) |i| {
                const c = self.circles[i];
                const dx = xmid - c.cx;
                var inside = c.r * c.r - dx * dx;
                if (inside < 0.0) inside = 0.0;
                const t = @sqrt(inside);
                const y_lo = c.cy - t;
                const y_hi = c.cy + t;

                const desc_lo = EndpointDesc{ .circle_id = i, .sign = -1 };
                const desc_hi = EndpointDesc{ .circle_id = i, .sign = 1 };
                endpoints_buffer.appendAssumeCapacity(.{ y_lo, desc_lo });
                endpoints_buffer.appendAssumeCapacity(.{ y_hi, desc_hi });
            }

            // Sort by y-value at xmid
            std.mem.sort(
                @TypeOf(endpoints_buffer.items[0]),
                endpoints_buffer.items,
                {},
                struct {
                    fn lessThan(_: void, a: @TypeOf(endpoints_buffer.items[0]), b: @TypeOf(endpoints_buffer.items[0])) bool {
                        return a[0] < b[0];
                    }
                }.lessThan,
            );

            // Extract order
            const order = try allocator.alloc(EndpointDesc, endpoints_buffer.items.len);
            for (endpoints_buffer.items, 0..) |ep, i| {
                order[i] = ep[1];
            }

            // Build rank map with pre-allocated capacity
            var rank_map = std.AutoHashMap(EndpointDesc, u32).init(allocator);
            defer rank_map.deinit();
            try rank_map.ensureTotalCapacity(@intCast(order.len));

            for (order, 0..) |desc, i| {
                rank_map.putAssumeCapacity(desc, @intCast(i));
            }

            // Build segment tree
            const m: u32 = @intCast(order.len);
            var root = try SegNode.build(allocator, order, 0, m - 1);

            // Insert all disks mutably (O(k log k) instead of O(k^2 log k))
            for (active_buffer.items) |i| {
                const lo_desc = EndpointDesc{ .circle_id = i, .sign = -1 };
                const hi_desc = EndpointDesc{ .circle_id = i, .sign = 1 };

                var l = rank_map.get(lo_desc).?;
                var r = rank_map.get(hi_desc).?;
                if (l > r) {
                    const tmp = l;
                    l = r;
                    r = tmp;
                }

                try root.insertIntervalMut(allocator, l, r, i);
            }

            xs.appendAssumeCapacity(xl);
            slabs.appendAssumeCapacity(Slab{
                .x_left = xl,
                .x_right = xr,
                .order = order,
                .root = root,
            });
        }

        self.slabs = try slabs.toOwnedSlice(allocator);
        self.xs = try xs.toOwnedSlice(allocator);
    }

    pub fn query(self: *const DiskStabbingDS, xq: f64, yq: f64, allocator: Allocator) ![]u32 {
        if (self.slabs.len == 0) return &[_]u32{};

        // Binary search for slab - optimized
        var slab_idx: usize = 0;
        if (self.xs.len > 0 and xq >= self.xs[0]) {
            // Standard binary search
            var left: usize = 0;
            var right: usize = self.xs.len;
            while (left < right) {
                const mid = left + (right - left) / 2;
                if (self.xs[mid] <= xq) {
                    left = mid + 1;
                } else {
                    right = mid;
                }
            }
            slab_idx = if (left > 0) left - 1 else 0;
        }

        if (slab_idx >= self.slabs.len) slab_idx = self.slabs.len - 1;
        const slab = self.slabs[slab_idx];

        if (slab.root == null) return &[_]u32{};

        // Query segment tree
        var candidates: ArrayList(u32) = .{};
        defer candidates.deinit(allocator);
        try slab.root.?.query(self.circles, xq, yq, &candidates, allocator);

        if (candidates.items.len == 0) return &[_]u32{};

        // Exact filter - preallocate result to avoid multiple allocations
        var result = try ArrayList(u32).initCapacity(allocator, candidates.items.len);
        defer result.deinit(allocator);

        // Inline containsPoint check for better performance
        for (candidates.items) |i| {
            const c = self.circles[i];
            const dx = xq - c.cx;
            const dy = yq - c.cy;
            if (dx * dx + dy * dy <= c.r * c.r) {
                result.appendAssumeCapacity(i);
            }
        }

        if (result.items.len == 0) return &[_]u32{};

        std.mem.sort(u32, result.items, {}, std.sort.asc(u32));
        return result.toOwnedSlice(allocator);
    }
};

// Tests
test "basic disk stabbing" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
        .{ .cx = 1.0, .cy = 0.5, .r = 1.0 },
        .{ .cx = -1.0, .cy = 0.5, .r = 1.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const result = try ds.query(0.5, 0.2, allocator);
    defer allocator.free(result);

    try std.testing.expect(result.len == 2);
    try std.testing.expect(result[0] == 0);
    try std.testing.expect(result[1] == 1);
}

test "empty query" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const result = try ds.query(10.0, 0.0, allocator);
    defer allocator.free(result);

    try std.testing.expect(result.len == 0);
}

test "single circle" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const inside = try ds.query(1.0, 0.0, allocator);
    defer allocator.free(inside);
    try std.testing.expect(inside.len == 1);

    const outside = try ds.query(3.0, 0.0, allocator);
    defer allocator.free(outside);
    try std.testing.expect(outside.len == 0);
}

test "two overlapping circles" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
        .{ .cx = 1.0, .cy = 0.0, .r = 2.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const result = try ds.query(0.5, 0.0, allocator);
    defer allocator.free(result);

    try std.testing.expect(result.len == 2);
}

test "nested circles" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 5.0 },
        .{ .cx = 0.0, .cy = 0.0, .r = 1.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    // Point in both
    const both = try ds.query(0.5, 0.0, allocator);
    defer allocator.free(both);
    try std.testing.expect(both.len == 2);

    // Point in outer only
    const outer = try ds.query(3.0, 0.0, allocator);
    defer allocator.free(outer);
    try std.testing.expect(outer.len == 1);
    try std.testing.expect(outer[0] == 0);
}

test "disjoint circles" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = -10.0, .cy = 0.0, .r = 1.0 },
        .{ .cx = 10.0, .cy = 0.0, .r = 1.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const left = try ds.query(-10.0, 0.0, allocator);
    defer allocator.free(left);
    try std.testing.expect(left.len == 1);
    try std.testing.expect(left[0] == 0);

    const right = try ds.query(10.0, 0.0, allocator);
    defer allocator.free(right);
    try std.testing.expect(right.len == 1);
    try std.testing.expect(right[0] == 1);

    const middle = try ds.query(0.0, 0.0, allocator);
    defer allocator.free(middle);
    try std.testing.expect(middle.len == 0);
}

test "many concentric circles" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 1.0 },
        .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
        .{ .cx = 0.0, .cy = 0.0, .r = 3.0 },
        .{ .cx = 0.0, .cy = 0.0, .r = 4.0 },
        .{ .cx = 0.0, .cy = 0.0, .r = 5.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    // Center - all circles
    const center = try ds.query(0.0, 0.0, allocator);
    defer allocator.free(center);
    try std.testing.expect(center.len == 5);

    // r=1.5 - should be in circles 1-4 (indices 1-4)
    const mid = try ds.query(1.5, 0.0, allocator);
    defer allocator.free(mid);
    try std.testing.expect(mid.len == 4);
}

test "negative coordinates" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = -3.0, .cy = -4.0, .r = 2.0 },
        .{ .cx = -6.0, .cy = -8.0, .r = 1.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const first = try ds.query(-3.0, -4.0, allocator);
    defer allocator.free(first);
    try std.testing.expect(first.len == 1);
    try std.testing.expect(first[0] == 0);

    const second = try ds.query(-6.0, -8.0, allocator);
    defer allocator.free(second);
    try std.testing.expect(second.len == 1);
    try std.testing.expect(second[0] == 1);
}

test "query extremes" {
    const allocator = std.testing.allocator;

    const circles = [_]Circle{
        .{ .cx = 0.0, .cy = 0.0, .r = 2.0 },
        .{ .cx = 10.0, .cy = 0.0, .r = 2.0 },
    };

    var ds = try DiskStabbingDS.init(allocator, &circles);
    defer ds.deinit();

    try ds.build();

    const far_left = try ds.query(-1000.0, 0.0, allocator);
    defer allocator.free(far_left);
    try std.testing.expect(far_left.len == 0);

    const far_right = try ds.query(1000.0, 0.0, allocator);
    defer allocator.free(far_right);
    try std.testing.expect(far_right.len == 0);

    const far_up = try ds.query(0.0, 1000.0, allocator);
    defer allocator.free(far_up);
    try std.testing.expect(far_up.len == 0);
}

test "persistent segment tree property" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const order = [_]EndpointDesc{
        .{ .circle_id = 0, .sign = -1 },
        .{ .circle_id = 0, .sign = 1 },
    };

    // Build initial tree
    const root0 = try SegNode.build(arena_allocator, &order, 0, 1);
    try std.testing.expect(root0.bucket.len == 0);

    // Insert disk 0
    const root1 = try root0.insertInterval(arena_allocator, 0, 1, 0);
    try std.testing.expect(root1.bucket.len == 1);
    try std.testing.expect(root0.bucket.len == 0); // Old unchanged!

    // Insert disk 1
    const root2 = try root1.insertInterval(arena_allocator, 0, 1, 1);
    try std.testing.expect(root2.bucket.len == 2);
    try std.testing.expect(root1.bucket.len == 1); // Old unchanged!
    try std.testing.expect(root0.bucket.len == 0); // Original unchanged!
}

test "random circles" {
    const allocator = std.testing.allocator;

    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    const n = 20;
    const circles = try allocator.alloc(Circle, n);
    defer allocator.free(circles);

    for (circles) |*c| {
        c.cx = (rng.float(f64) - 0.5) * 20.0;
        c.cy = (rng.float(f64) - 0.5) * 20.0;
        c.r = rng.float(f64) * 4.0 + 0.5;
    }

    var ds = try DiskStabbingDS.init(allocator, circles);
    defer ds.deinit();

    try ds.build();

    // Test multiple random queries
    for (0..100) |_| {
        const xq = (rng.float(f64) - 0.5) * 25.0;
        const yq = (rng.float(f64) - 0.5) * 25.0;

        const result = try ds.query(xq, yq, allocator);
        defer allocator.free(result);

        // Brute force verification
        for (result) |i| {
            try std.testing.expect(circles[i].containsPoint(xq, yq));
        }

        // Check completeness
        for (circles, 0..) |c, i| {
            if (c.containsPoint(xq, yq)) {
                var found = false;
                for (result) |r| {
                    if (r == i) {
                        found = true;
                        break;
                    }
                }
                try std.testing.expect(found);
            }
        }
    }
}

test "determinism" {
    const allocator = std.testing.allocator;

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

    // Test same queries on both
    const queries = [_]struct { f64, f64 }{
        .{ 0.0, 0.0 },
        .{ 0.5, 0.2 },
        .{ -0.5, 0.3 },
        .{ 1.5, 0.0 },
    };

    for (queries) |q| {
        const r1 = try ds1.query(q[0], q[1], allocator);
        defer allocator.free(r1);

        const r2 = try ds2.query(q[0], q[1], allocator);
        defer allocator.free(r2);

        try std.testing.expect(r1.len == r2.len);
        for (r1, r2) |v1, v2| {
            try std.testing.expect(v1 == v2);
        }
    }
}
