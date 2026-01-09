#!/usr/bin/env pypy3
"""Test persistent disk stabbing structure"""

from dataclasses import dataclass
from math import sqrt
from bisect import bisect_right
from typing import Optional, List, Tuple, Dict, Set

# Inline minimal definitions needed for testing
@dataclass(frozen=True)
class Circle:
    cx: float
    cy: float
    r: float

@dataclass(frozen=True, order=True)
class EndpointDesc:
    circle_id: int
    sign: int  # -1 for lower, +1 for upper

    def eval(self, circles: List[Circle], x: float) -> float:
        c = circles[self.circle_id]
        dx = x - c.cx
        inside = c.r * c.r - dx * dx
        if inside < 0.0:
            inside = 0.0
        return c.cy + self.sign * sqrt(inside)

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

def seg_stab_query(node: Optional[SegNode],
                   circles: List[Circle],
                   xq: float,
                   yq: float,
                   out: Set[int]) -> None:
    cur = node
    while cur is not None:
        out.update(cur.bucket)
        if cur.left is None and cur.right is None:
            break
        assert cur.split is not None
        v = cur.split.eval(circles, xq)
        if yq <= v:
            cur = cur.left
        else:
            cur = cur.right

@dataclass
class Slab:
    x_left: float
    x_right: float
    order: List[EndpointDesc]
    root: Optional[SegNode]

class DiskStabbingDS:
    def __init__(self, circles):
        self.circles = circles
        self._slabs = []
        self._xs = []
        self._built = False

    def build(self) -> None:
        n = len(self.circles)
        if n == 0:
            self._built = True
            return

        # Simple slab at x=0
        xmid = 0.0
        active_mid = [i for i, c in enumerate(self.circles)
                      if (c.cx - c.r) <= xmid <= (c.cx + c.r)]

        if not active_mid:
            self._built = True
            return

        endpoints: List[Tuple[float, EndpointDesc]] = []
        for i in active_mid:
            endpoints.append((EndpointDesc(i, -1).eval(self.circles, xmid), EndpointDesc(i, -1)))
            endpoints.append((EndpointDesc(i, +1).eval(self.circles, xmid), EndpointDesc(i, +1)))

        endpoints.sort(key=lambda t: t[0])
        order = [desc for _, desc in endpoints]

        rank: Dict[EndpointDesc, int] = {desc: idx for idx, desc in enumerate(order)}

        m = len(order)
        root = build_rank_segtree(order, 0, m - 1)

        for i in active_mid:
            lo_desc = EndpointDesc(i, -1)
            hi_desc = EndpointDesc(i, +1)
            l = rank[lo_desc]
            r = rank[hi_desc]
            if l > r:
                l, r = r, l
            root = seg_insert_interval(root, l, r, i)

        self._slabs = [Slab(-10.0, 10.0, order, root)]
        self._xs = [-10.0]
        self._built = True

    def query(self, xq: float, yq: float) -> List[int]:
        if not self._built or not self._slabs:
            return []

        slab = self._slabs[0]
        if slab.root is None:
            return []

        cand: Set[int] = set()
        seg_stab_query(slab.root, self.circles, xq, yq, cand)

        out = []
        for i in cand:
            c = self.circles[i]
            dx = xq - c.cx
            dy = yq - c.cy
            if dx*dx + dy*dy <= c.r*c.r:
                out.append(i)
        return sorted(out)

# Test
circles = [
    Circle(0.0, 0.0, 2.0),
    Circle(1.0, 0.5, 1.0),
    Circle(-1.0, 0.5, 1.0),
]
ds = DiskStabbingDS(circles)
ds.build()
result = ds.query(0.5, 0.2)
print(f'Query result: {result}')
print('Basic test passed!' if result == [0, 1] else f'Basic test FAILED! Expected [0, 1], got {result}')

# Test persistence property
print('\nTesting persistence...')
# Create a simple tree
order = [EndpointDesc(0, -1), EndpointDesc(0, 1)]
root1 = build_rank_segtree(order, 0, 1)
print(f'Initial root bucket: {root1.bucket}')

# Insert disk 0
root2 = seg_insert_interval(root1, 0, 1, 0)
print(f'After insert disk 0, new root bucket: {root2.bucket}')
print(f'Old root unchanged: {root1.bucket}')

# Insert disk 1 into root2
root3 = seg_insert_interval(root2, 0, 1, 1)
print(f'After insert disk 1, new root bucket: {root3.bucket}')
print(f'root2 unchanged: {root2.bucket}')
print(f'root1 still unchanged: {root1.bucket}')

if root1.bucket == () and root2.bucket == (0,) and root3.bucket == (0, 1):
    print('\nPersistence test PASSED!')
else:
    print('\nPersistence test FAILED!')

print('\nAll tests completed.')
