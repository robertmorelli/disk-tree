const std = @import("std");
const Allocator = std.mem.Allocator;

/// A treap (tree + heap) for maintaining y-sorted active circles in sweep line
/// Key: y-coordinate, Value: circle ID, Priority: random (for balancing)
pub fn Treap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            key: K,
            value: V,
            priority: u64,
            left: ?*Node = null,
            right: ?*Node = null,
        };

        root: ?*Node = null,
        allocator: Allocator,
        rng: std.Random.DefaultPrng,

        pub fn init(allocator: Allocator, seed: u64) Self {
            return .{
                .allocator = allocator,
                .rng = std.Random.DefaultPrng.init(seed),
                .root = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.freeTree(self.root);
        }

        fn freeTree(self: *Self, node: ?*Node) void {
            if (node) |n| {
                self.freeTree(n.left);
                self.freeTree(n.right);
                self.allocator.destroy(n);
            }
        }

        /// Rotate right: make left child the new root
        fn rotateRight(y: *Node) *Node {
            const x = y.left.?;
            const t2 = x.right;

            x.right = y;
            y.left = t2;

            return x;
        }

        /// Rotate left: make right child the new root
        fn rotateLeft(x: *Node) *Node {
            const y = x.right.?;
            const t2 = y.left;

            y.left = x;
            x.right = t2;

            return y;
        }

        /// Insert a key-value pair
        pub fn insert(self: *Self, key: K, value: V) !void {
            const priority = self.rng.random().int(u64);
            self.root = try self.insertNode(self.root, key, value, priority);
        }

        fn insertNode(self: *Self, node: ?*Node, key: K, value: V, priority: u64) !*Node {
            if (node == null) {
                const new_node = try self.allocator.create(Node);
                new_node.* = .{
                    .key = key,
                    .value = value,
                    .priority = priority,
                };
                return new_node;
            }

            var n = node.?;

            if (key < n.key) {
                n.left = try self.insertNode(n.left, key, value, priority);
                // Maintain heap property
                if (n.left.?.priority > n.priority) {
                    return rotateRight(n);
                }
            } else {
                n.right = try self.insertNode(n.right, key, value, priority);
                // Maintain heap property
                if (n.right.?.priority > n.priority) {
                    return rotateLeft(n);
                }
            }

            return n;
        }

        /// Remove a node by key
        pub fn remove(self: *Self, key: K) void {
            self.root = self.removeNode(self.root, key);
        }

        fn removeNode(self: *Self, node: ?*Node, key: K) ?*Node {
            if (node == null) return null;

            var n = node.?;

            if (key < n.key) {
                n.left = self.removeNode(n.left, key);
            } else if (key > n.key) {
                n.right = self.removeNode(n.right, key);
            } else {
                // Found the node to delete
                if (n.left == null) {
                    const right = n.right;
                    self.allocator.destroy(n);
                    return right;
                } else if (n.right == null) {
                    const left = n.left;
                    self.allocator.destroy(n);
                    return left;
                } else {
                    // Both children exist - rotate down the one with lower priority
                    if (n.left.?.priority > n.right.?.priority) {
                        const new_root = rotateRight(n);
                        new_root.right = self.removeNode(new_root.right, key);
                        return new_root;
                    } else {
                        const new_root = rotateLeft(n);
                        new_root.left = self.removeNode(new_root.left, key);
                        return new_root;
                    }
                }
            }

            return n;
        }

        /// Find the node with the given key
        pub fn find(self: *const Self, key: K) ?V {
            var current = self.root;
            while (current) |node| {
                if (key < node.key) {
                    current = node.left;
                } else if (key > node.key) {
                    current = node.right;
                } else {
                    return node.value;
                }
            }
            return null;
        }

        /// Get all values in sorted order (for debugging/testing)
        pub fn inorderValues(self: *const Self, allocator: Allocator) ![]V {
            var result: std.ArrayList(V) = .{};
            defer result.deinit(allocator);

            try self.inorderTraversal(self.root, &result, allocator);
            return result.toOwnedSlice(allocator);
        }

        fn inorderTraversal(self: *const Self, node: ?*Node, result: *std.ArrayList(V), allocator: Allocator) !void {
            if (node) |n| {
                try self.inorderTraversal(n.left, result, allocator);
                try result.append(allocator, n.value);
                try self.inorderTraversal(n.right, result, allocator);
            }
        }

        /// Find predecessor (largest key < given key)
        pub fn predecessor(self: *const Self, key: K) ?struct { K, V } {
            var current = self.root;
            var pred: ?*Node = null;

            while (current) |node| {
                if (node.key < key) {
                    pred = node;
                    current = node.right;
                } else {
                    current = node.left;
                }
            }

            if (pred) |p| {
                return .{ p.key, p.value };
            }
            return null;
        }

        /// Find successor (smallest key > given key)
        pub fn successor(self: *const Self, key: K) ?struct { K, V } {
            var current = self.root;
            var succ: ?*Node = null;

            while (current) |node| {
                if (node.key > key) {
                    succ = node;
                    current = node.left;
                } else {
                    current = node.right;
                }
            }

            if (succ) |s| {
                return .{ s.key, s.value };
            }
            return null;
        }

        /// Get immediate neighbors (predecessor and successor)
        pub fn neighbors(self: *const Self, key: K) struct { ?V, ?V } {
            const pred = self.predecessor(key);
            const succ = self.successor(key);

            return .{
                if (pred) |p| p[1] else null,
                if (succ) |s| s[1] else null,
            };
        }

        /// Count nodes in tree
        pub fn count(self: *const Self) usize {
            return countNodes(self.root);
        }

        fn countNodes(node: ?*Node) usize {
            if (node) |n| {
                return 1 + countNodes(n.left) + countNodes(n.right);
            }
            return 0;
        }
    };
}

// Tests
test "treap basic operations" {
    const allocator = std.testing.allocator;

    var treap = Treap(f64, u32).init(allocator, 42);
    defer treap.deinit();

    try treap.insert(5.0, 50);
    try treap.insert(3.0, 30);
    try treap.insert(7.0, 70);
    try treap.insert(2.0, 20);
    try treap.insert(4.0, 40);

    // Test find
    try std.testing.expectEqual(@as(?u32, 50), treap.find(5.0));
    try std.testing.expectEqual(@as(?u32, 30), treap.find(3.0));
    try std.testing.expectEqual(@as(?u32, null), treap.find(99.0));

    // Test inorder traversal
    const values = try treap.inorderValues(allocator);
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 5), values.len);
    try std.testing.expectEqual(@as(u32, 20), values[0]);
    try std.testing.expectEqual(@as(u32, 30), values[1]);
    try std.testing.expectEqual(@as(u32, 40), values[2]);
    try std.testing.expectEqual(@as(u32, 50), values[3]);
    try std.testing.expectEqual(@as(u32, 70), values[4]);
}

test "treap removal" {
    const allocator = std.testing.allocator;

    var treap = Treap(f64, u32).init(allocator, 42);
    defer treap.deinit();

    try treap.insert(5.0, 50);
    try treap.insert(3.0, 30);
    try treap.insert(7.0, 70);
    try treap.insert(2.0, 20);

    try std.testing.expectEqual(@as(?u32, 30), treap.find(3.0));

    treap.remove(3.0);

    try std.testing.expectEqual(@as(?u32, null), treap.find(3.0));
    try std.testing.expectEqual(@as(?u32, 50), treap.find(5.0));
    try std.testing.expectEqual(@as(?u32, 20), treap.find(2.0));
}

test "treap predecessor and successor" {
    const allocator = std.testing.allocator;

    var treap = Treap(f64, u32).init(allocator, 42);
    defer treap.deinit();

    try treap.insert(5.0, 50);
    try treap.insert(3.0, 30);
    try treap.insert(7.0, 70);
    try treap.insert(2.0, 20);
    try treap.insert(9.0, 90);

    // Predecessor of 5.0 should be 3.0 -> 30
    const pred5 = treap.predecessor(5.0);
    try std.testing.expect(pred5 != null);
    try std.testing.expectEqual(@as(f64, 3.0), pred5.?[0]);
    try std.testing.expectEqual(@as(u32, 30), pred5.?[1]);

    // Successor of 5.0 should be 7.0 -> 70
    const succ5 = treap.successor(5.0);
    try std.testing.expect(succ5 != null);
    try std.testing.expectEqual(@as(f64, 7.0), succ5.?[0]);
    try std.testing.expectEqual(@as(u32, 70), succ5.?[1]);

    // Predecessor of 2.0 should be null
    const pred2 = treap.predecessor(2.0);
    try std.testing.expect(pred2 == null);

    // Successor of 9.0 should be null
    const succ9 = treap.successor(9.0);
    try std.testing.expect(succ9 == null);
}

test "treap neighbors" {
    const allocator = std.testing.allocator;

    var treap = Treap(f64, u32).init(allocator, 42);
    defer treap.deinit();

    try treap.insert(5.0, 50);
    try treap.insert(3.0, 30);
    try treap.insert(7.0, 70);

    const neighb = treap.neighbors(5.0);
    try std.testing.expectEqual(@as(?u32, 30), neighb[0]); // predecessor
    try std.testing.expectEqual(@as(?u32, 70), neighb[1]); // successor
}
