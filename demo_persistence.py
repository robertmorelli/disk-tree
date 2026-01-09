#!/usr/bin/env pypy3
"""
Demonstration of persistent segment tree properties in disk stabbing structure.

This shows how persistence enables O(n log n) construction by reusing structure
across versions instead of rebuilding from scratch.
"""

from dataclasses import dataclass
from math import sqrt
from typing import Optional, List, Tuple, Dict

@dataclass(frozen=True, order=True)
class EndpointDesc:
    circle_id: int
    sign: int

    def eval(self, circles, x: float) -> float:
        return float(self.circle_id * 10 + self.sign)  # Simplified for demo

@dataclass
class SegNode:
    lo: int
    hi: int
    split: Optional[EndpointDesc]
    left: Optional["SegNode"]
    right: Optional["SegNode"]
    bucket: Tuple[int, ...]

def build_rank_segtree(order: List[EndpointDesc], lo: int, hi: int) -> SegNode:
    if lo == hi:
        return SegNode(lo, hi, order[lo], None, None, ())
    mid = (lo + hi) // 2
    left = build_rank_segtree(order, lo, mid)
    right = build_rank_segtree(order, mid + 1, hi)
    return SegNode(lo, hi, order[mid], left, right, ())

def seg_insert_interval(node: SegNode, ql: int, qr: int, disk_id: int) -> SegNode:
    """Persistent insert - returns NEW root, old root unchanged"""
    if ql <= node.lo and node.hi <= qr:
        new_bucket = node.bucket + (disk_id,)
        return SegNode(node.lo, node.hi, node.split, node.left, node.right, new_bucket)

    mid = (node.lo + node.hi) // 2
    new_left = node.left
    new_right = node.right

    if ql <= mid and node.left is not None:
        new_left = seg_insert_interval(node.left, ql, qr, disk_id)
    if qr > mid and node.right is not None:
        new_right = seg_insert_interval(node.right, ql, qr, disk_id)

    return SegNode(node.lo, node.hi, node.split, new_left, new_right, node.bucket)

def count_nodes(node):
    if node is None:
        return 0
    return 1 + count_nodes(node.left) + count_nodes(node.right)

def count_shared_nodes(node1, node2):
    """Count nodes that are the same object (shared via persistence)"""
    if node1 is None or node2 is None:
        return 0
    shared = 1 if node1 is node2 else 0
    shared += count_shared_nodes(node1.left, node2.left)
    shared += count_shared_nodes(node1.right, node2.right)
    return shared

def print_tree_info(name, node, prev_node=None):
    total = count_nodes(node)
    shared = count_shared_nodes(prev_node, node) if prev_node else 0
    new = total - shared
    print(f"{name:20} Total: {total:3} nodes  |  New: {new:3}  |  Shared: {shared:3}")

print("=" * 70)
print("PERSISTENT SEGMENT TREE DEMONSTRATION")
print("=" * 70)
print("\nScenario: Building segment trees for disk stabbing slabs")
print("With persistence, we create O(log n) new nodes per insert")
print("Without persistence, we'd rebuild the entire tree each time\n")

# Create initial tree structure
order = [EndpointDesc(i, s) for i in range(4) for s in [-1, 1]]
root0 = build_rank_segtree(order, 0, len(order) - 1)

print("STEP 0: Build empty tree structure")
print_tree_info("root0 (empty)", root0)
print(f"  └─ This is the base structure: {count_nodes(root0)} nodes\n")

# Insert disk 0
root1 = seg_insert_interval(root0, 0, 7, disk_id=0)
print("STEP 1: Insert disk 0 [ranks 0-7] -> root1")
print_tree_info("root1", root1, root0)
print(f"  └─ Only {count_nodes(root1) - count_nodes(root0)} new nodes created (path copying)")
print(f"  └─ Old root0 unchanged: {count_nodes(root0)} nodes\n")

# Insert disk 1
root2 = seg_insert_interval(root1, 2, 5, disk_id=1)
print("STEP 2: Insert disk 1 [ranks 2-5] -> root2")
print_tree_info("root2", root2, root1)
print(f"  └─ Reuses structure from root1")
print(f"  └─ root1 still intact: {count_nodes(root1)} nodes")
print(f"  └─ root0 still intact: {count_nodes(root0)} nodes\n")

# Insert disk 2
root3 = seg_insert_interval(root2, 1, 3, disk_id=2)
print("STEP 3: Insert disk 2 [ranks 1-3] -> root3")
print_tree_info("root3", root3, root2)
print()

# Show all versions still accessible
print("=" * 70)
print("VERIFICATION: All versions still accessible")
print("=" * 70)
print_tree_info("root0 (empty)", root0)
print_tree_info("root1 (disk 0)", root1)
print_tree_info("root2 (disks 0,1)", root2)
print_tree_info("root3 (disks 0,1,2)", root3)

print("\n" + "=" * 70)
print("COMPLEXITY ANALYSIS")
print("=" * 70)

tree_height = 3  # log2(8) = 3 for 8 endpoints
print(f"Tree height: {tree_height} (log n)")
print(f"Nodes per insert: ~{tree_height} (one per level in update path)")
print()

print("For disk stabbing with n disks:")
print("  • O(n) slabs across sweep")
print("  • O(n) total disk-slab insertions")
print("  • O(log n) nodes per insertion (path copying)")
print("  • Total: O(n log n) nodes created")
print()
print("Without persistence:")
print("  • O(n) slabs")
print("  • O(n log n) to build each slab from scratch")
print("  • Total: O(n² log n) ❌")
print()

print("=" * 70)
print("Memory sharing demonstration")
print("=" * 70)

# Count unique nodes across all versions
all_nodes = set()

def collect_node_ids(node, node_set):
    if node is None:
        return
    node_set.add(id(node))
    collect_node_ids(node.left, node_set)
    collect_node_ids(node.right, node_set)

for name, root in [("root0", root0), ("root1", root1), ("root2", root2), ("root3", root3)]:
    nodes = set()
    collect_node_ids(root, nodes)
    all_nodes.update(nodes)
    print(f"{name}: {len(nodes)} unique nodes")

print(f"\nTotal unique nodes across all 4 versions: {len(all_nodes)}")
print(f"If we rebuilt each time: {sum(count_nodes(r) for r in [root0, root1, root2, root3])}")
print(f"Saved: {sum(count_nodes(r) for r in [root0, root1, root2, root3]) - len(all_nodes)} nodes via sharing")

print("\n" + "=" * 70)
print("This demonstrates the core principle enabling O(n log n) disk stabbing!")
print("=" * 70)
