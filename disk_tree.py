
from __future__ import annotations
from dataclasses import dataclass
from typing import Iterable
import matplotlib.pyplot as plt

from dataclasses import dataclass
from math import sqrt
from bisect import bisect_right
import heapq
from typing import Optional, List, Tuple, Dict, Set


def circle_y_interval_at_x(c: Circle, x: float) -> Tuple[float, float] | None:
    dx = x - c.cx
    inside = c.r*c.r - dx*dx
    if inside < 0.0:
        return None
    t = sqrt(inside)
    return (c.cy - t, c.cy + t)


def collect_segtree_path(root: Optional[SegNode], circles: List[Circle], xq: float, yq: float) -> List[Tuple[int, float]]:
    """
    Return list of (rank_index, y_threshold) along the descent path.
    rank_index is node.split's rank in slab order if you pass rank map, but we don't have it here,
    so we return (node.lo,node.hi) midpoint approximation? We'll just return y_thresholds in order.
    """
    out = []
    cur = root
    while cur is not None:
        if cur.split is None:
            break
        yth = cur.split.eval(circles, xq)
        out.append((cur.lo, yth))  # cur.lo is just an identifier; not important for drawing
        if cur.left is None and cur.right is None:
            break
        cur = cur.left if yq <= yth else cur.right
    return out


def iter_segnodes(root: Optional[SegNode]) -> Iterable[SegNode]:
    if root is None:
        return
    stack = [root]
    while stack:
        n = stack.pop()
        yield n
        if n.right is not None:
            stack.append(n.right)
        if n.left is not None:
            stack.append(n.left)


def choose_slab(ds: DiskStabbingDS, xq: float | None = None, slab_index: int | None = None) -> Tuple[int, Slab]:
    if not ds._built:
        raise RuntimeError("build() first")
    if not ds._slabs:
        raise RuntimeError("no slabs to visualize (no circles or no events)")

    if slab_index is not None:
        slab_index = max(0, min(slab_index, len(ds._slabs) - 1))
        return slab_index, ds._slabs[slab_index]

    if xq is None:
        return 0, ds._slabs[0]

    j = bisect_right(ds._xs, xq) - 1
    if j < 0:
        j = 0
    if j >= len(ds._slabs):
        j = len(ds._slabs) - 1
    return j, ds._slabs[j]


def visualize(ds: DiskStabbingDS,
              filename: str = "disk_tree_viz.png",
              query: Tuple[float, float] | None = None,
              slab_index: int | None = None,
              show: bool = False) -> None:
    """
    Save an image showing:
      - all disks
      - left-side chord segments for the chosen slab at xmid
      - optional query point and decision thresholds

    If query is provided, slab is chosen by query.x unless slab_index is provided.
    """
    if query is not None:
        xq, yq = query
        si, slab = choose_slab(ds, xq=xq, slab_index=slab_index)
    else:
        xq = yq = None
        si, slab = choose_slab(ds, xq=None, slab_index=slab_index)

    circles = ds.circles

    # Determine plot bounds from circles
    if circles:
        xmin = min(c.cx - c.r for c in circles)
        xmax = max(c.cx + c.r for c in circles)
        ymin = min(c.cy - c.r for c in circles)
        ymax = max(c.cy + c.r for c in circles)
    else:
        xmin = ymin = -1.0
        xmax = ymax = 1.0

    # Add margins and room on the left for "segments"
    xrng = xmax - xmin
    yrng = ymax - ymin
    if xrng == 0: xrng = 1.0
    if yrng == 0: yrng = 1.0
    pad_x = 0.25 * xrng
    pad_y = 0.15 * yrng

    seg_x = xmin - 0.35 * xrng  # where we draw the left-side segments
    plot_xmin = xmin - pad_x - 0.40 * xrng
    plot_xmax = xmax + pad_x
    plot_ymin = ymin - pad_y
    plot_ymax = ymax + pad_y

    # Pick a representative x in the slab
    xmid = 0.5 * (slab.x_left + slab.x_right)

    fig, ax = plt.subplots()
    ax.set_aspect("equal", adjustable="box")
    ax.set_xlim(plot_xmin, plot_xmax)
    ax.set_ylim(plot_ymin, plot_ymax)

    ax.set_title(f"DiskStabbingDS slab {si}: x in [{slab.x_left:.3g}, {slab.x_right:.3g}], xmid={xmid:.3g}")

    # Draw slab boundaries and xmid
    ax.axvline(slab.x_left, linestyle="--")
    ax.axvline(slab.x_right, linestyle="--")
    ax.axvline(xmid, linestyle=":")

    # Draw circles
    for i, c in enumerate(circles):
        circ = plt.Circle((c.cx, c.cy), c.r, fill=False)
        ax.add_patch(circ)
        ax.text(c.cx, c.cy, str(i), fontsize=8, ha="center", va="center")

    # Draw left-side chord segments at xmid for disks active at xmid
    active_mid = []
    for i, c in enumerate(circles):
        iv = circle_y_interval_at_x(c, xmid)
        if iv is None:
            continue
        active_mid.append(i)
        y0, y1 = iv
        ax.plot([seg_x, seg_x], [y0, y1], linewidth=2)
        ax.text(seg_x, 0.5*(y0+y1), f"{i}", fontsize=8, ha="right", va="center")

    ax.text(seg_x, plot_ymax - 0.05*yrng, "slab chords @ xmid", fontsize=9, ha="left", va="top")

    # If query: draw point, highlight true disks, and decision thresholds
    if query is not None:
        ax.plot([xq], [yq], marker="o")
        got = ds.query(xq, yq, exact_filter=True)
        brute = []
        for i, c in enumerate(circles):
            dx = xq - c.cx
            dy = yq - c.cy
            if dx*dx + dy*dy <= c.r*c.r:
                brute.append(i)

        # annotate
        ax.text(plot_xmin + 0.02*xrng, plot_ymax - 0.12*yrng,
                f"query=({xq:.3g},{yq:.3g})\nDS={got}\nbrute={brute}",
                fontsize=9, ha="left", va="top")

        # Highlight disks that contain query (thicker outline)
        for i in brute:
            c = circles[i]
            hi = plt.Circle((c.cx, c.cy), c.r, fill=False, linewidth=2.5)
            ax.add_patch(hi)

        # Decision thresholds (horizontal lines at evaluated split y-values)
        if slab.root is not None:
            path = collect_segtree_path(slab.root, circles, xq, yq)
            for _, yth in path:
                ax.axhline(yth, linestyle=":", linewidth=1.0)
            ax.text(plot_xmin + 0.02*xrng, plot_ymax - 0.25*yrng,
                    f"path splits: {len(path)} levels",
                    fontsize=9, ha="left", va="top")

    ax.grid(True, linestyle=":", linewidth=0.5)
    fig.savefig(filename, dpi=200, bbox_inches="tight")
    if show:
        plt.show()
    plt.close(fig)





# -----------------------------
# Geometry primitives
# -----------------------------

@dataclass(frozen=True)
class Circle:
    cx: float
    cy: float
    r: float


@dataclass(frozen=True, order=True)
class EndpointDesc:
    """Portable description of an endpoint function y = cy +/- sqrt(r^2 - (x-cx)^2)."""
    circle_id: int
    sign: int  # -1 for lower, +1 for upper

    def eval(self, circles: List[Circle], x: float) -> float:
        c = circles[self.circle_id]
        dx = x - c.cx
        # assume x lies in the slab where this endpoint is defined for active circles
        inside = c.r * c.r - dx * dx
        if inside < 0.0:
            # outside the circle's vertical chord; ignore edge cases
            inside = 0.0
        return c.cy + self.sign * sqrt(inside)


def circle_circle_intersections(c1: Circle, c2: Circle) -> List[Tuple[float, float]]:
    """
    Return intersection points (x,y) of two circles (0,1,2 points).
    Ignores edge cases not mentioned (tangency, coincident circles).
    """
    x0, y0, r0 = c1.cx, c1.cy, c1.r
    x1, y1, r1 = c2.cx, c2.cy, c2.r

    dx = x1 - x0
    dy = y1 - y0
    d2 = dx*dx + dy*dy
    d = sqrt(d2)

    # no intersection or one inside the other (ignore tangency)
    if d == 0.0:
        return []
    if d > r0 + r1:
        return []
    if d < abs(r0 - r1):
        return []

    # circle-circle intersection formula
    a = (r0*r0 - r1*r1 + d2) / (2*d)
    h2 = r0*r0 - a*a
    if h2 <= 0.0:
        return []  # ignore tangency
    h = sqrt(h2)

    xm = x0 + a * dx / d
    ym = y0 + a * dy / d

    rx = -dy * (h / d)
    ry =  dx * (h / d)

    p1 = (xm + rx, ym + ry)
    p2 = (xm - rx, ym - ry)
    return [p1, p2]


# -----------------------------
# Segment tree over ranks
# -----------------------------

@dataclass
class SegNode:
    lo: int
    hi: int
    split: Optional[EndpointDesc]  # descriptor of E_k for comparisons
    left: Optional["SegNode"]
    right: Optional["SegNode"]
    bucket: List[int]  # disk ids whose rank-interval fully covers this node


def build_rank_segtree(order: List[EndpointDesc], lo: int, hi: int) -> SegNode:
    """
    Build a segment tree over ranks [lo, hi], inclusive.
    Node's split is the endpoint descriptor at mid rank (portable).
    """
    if lo == hi:
        return SegNode(lo, hi, order[lo], None, None, [])
    mid = (lo + hi) // 2
    left = build_rank_segtree(order, lo, mid)
    right = build_rank_segtree(order, mid + 1, hi)
    return SegNode(lo, hi, order[mid], left, right, [])


def seg_insert_interval(node: SegNode, ql: int, qr: int, disk_id: int) -> None:
    """Canonical cover insert of [ql, qr] into node buckets."""
    if ql <= node.lo and node.hi <= qr:
        node.bucket.append(disk_id)
        return
    mid = (node.lo + node.hi) // 2
    if ql <= mid and node.left is not None:
        seg_insert_interval(node.left, ql, qr, disk_id)
    if qr > mid and node.right is not None:
        seg_insert_interval(node.right, ql, qr, disk_id)


def seg_stab_query(node: Optional[SegNode],
                   circles: List[Circle],
                   xq: float,
                   yq: float,
                   out: Set[int]) -> None:
    """Descend rank segtree by evaluating split endpoint functions at xq."""
    cur = node
    while cur is not None:
        out.update(cur.bucket)
        if cur.left is None and cur.right is None:
            break
        # Evaluate split key at query x
        assert cur.split is not None
        v = cur.split.eval(circles, xq)
        if yq <= v:
            cur = cur.left
        else:
            cur = cur.right


# -----------------------------
# Frozen sweep disk stabbing DS
# -----------------------------

@dataclass
class Slab:
    x_left: float              # slab starts at this x (event boundary)
    x_right: float             # slab ends at this x (next event boundary)
    order: List[EndpointDesc]  # endpoint descriptors sorted by y at a representative x
    root: Optional[SegNode]    # segtree built over ranks for this slab


class DiskStabbingDS:
    """
    Frozen sweep disk stabbing structure.

    Construction:
      - event heap over x
      - for each slab between successive event x's:
          - pick x_mid
          - compute active disks, build endpoint order by eval at x_mid
          - build rank segtree, insert each active disk interval by ranks
      - output is list of (x_left, slab) tuples (de-duplicated by dict during build)

    Query:
      - binary search slab by x
      - descend segtree using split endpoint eval at xq
      - (optional) exact filter by distance check
    """

    def __init__(self, circles):
        self.circles = circles
        self._slabs = []
        self._xs = []
        self._built = False

    def build(self) -> None:
        n = len(self.circles)
        events: List[Tuple[float, int, Tuple]] = []
        # event types: 0 = start, 1 = end, 2 = intersection-x
        START, END, XING = 0, 1, 2

        # Push start/end events for each disk
        for i, c in enumerate(self.circles):
            xl = c.cx - c.r
            xr = c.cx + c.r
            events.append((xl, START, (i,)))
            events.append((xr, END, (i,)))

        # Push circle-circle intersection x-coordinates (both points)
        for i in range(n):
            for j in range(i + 1, n):
                pts = circle_circle_intersections(self.circles[i], self.circles[j])
                for (x, y) in pts:
                    events.append((x, XING, (i, j, y)))

        # Heapify for sweep order (you wanted heapq)
        heapq.heapify(events)

        # Active set updated by start/end
        active: Set[int] = set()

        # We’ll collect unique x boundaries in an ordered list
        x_boundaries: List[float] = []
        last_x: Optional[float] = None

        # Process heap and gather boundaries in increasing x
        # (Ignoring tie-handling edge cases)
        while events:
            x, etype, data = heapq.heappop(events)
            if last_x is None or x != last_x:
                x_boundaries.append(x)
                last_x = x
            if etype == START:
                (i,) = data
                active.add(i)
            elif etype == END:
                (i,) = data
                if i in active:
                    active.remove(i)
            else:
                # intersection event doesn't directly change active set
                pass

        # Build slabs between consecutive boundaries
        # Use a dict for de-dup/overwrite during construction, then emit sorted list
        slab_dict: Dict[float, Slab] = {}

        for k in range(len(x_boundaries) - 1):
            xl = x_boundaries[k]
            xr = x_boundaries[k + 1]
            if xr <= xl:
                continue
            xmid = 0.5 * (xl + xr)

            # Active disks for this slab: those whose x-range covers xmid
            active_mid = [i for i,c in enumerate(self.circles)
              if (c.cx - c.r) <= xmid <= (c.cx + c.r)]
            if not active_mid:
                slab_dict[xl] = Slab(xl, xr, [], None)
                continue

            # Build and sort endpoint descriptors by y at xmid
            endpoints: List[Tuple[float, EndpointDesc]] = []
            for i in active_mid:
                endpoints.append((EndpointDesc(i, -1).eval(self.circles, xmid), EndpointDesc(i, -1)))
                endpoints.append((EndpointDesc(i, +1).eval(self.circles, xmid), EndpointDesc(i, +1)))

            endpoints.sort(key=lambda t: t[0])
            order = [desc for _, desc in endpoints]

            # Map desc -> rank index
            rank: Dict[EndpointDesc, int] = {desc: idx for idx, desc in enumerate(order)}

            # Build segtree over ranks [0..m-1]
            m = len(order)
            root = build_rank_segtree(order, 0, m - 1)

            # Insert each disk's interval by ranks
            for i in active_mid:
                lo_desc = EndpointDesc(i, -1)
                hi_desc = EndpointDesc(i, +1)
                l = rank[lo_desc]
                r = rank[hi_desc]
                if l > r:
                    l, r = r, l
                seg_insert_interval(root, l, r, i)

            slab_dict[xl] = Slab(xl, xr, order, root)

        # Emit final de-duplicated sorted list of slabs (list of tuples shape)
        self._xs = sorted(slab_dict.keys())
        self._slabs = [slab_dict[x] for x in self._xs]
        self._built = True

    def query(self, xq: float, yq: float, exact_filter: bool = True) -> List[int]:
        if not self._built:
            raise RuntimeError("Call build() first.")
        if not self._slabs:
            return []

        j = bisect_right(self._xs, xq) - 1
        if j < 0:
            return []
        slab = self._slabs[j]

        if slab.root is None:
            return []

        cand: Set[int] = set()
        seg_stab_query(slab.root, self.circles, xq, yq, cand)

        if not exact_filter:
            return sorted(cand)

        # Exact containment check (recommended)
        out = []
        for i in cand:
            c = self.circles[i]
            dx = xq - c.cx
            dy = yq - c.cy
            if dx*dx + dy*dy <= c.r*c.r:
                out.append(i)
        return sorted(out)


# -----------------------------
# Example usage
# -----------------------------
if __name__ == "__main__":
    circles = [
        Circle(0.0, 0.0, 2.0),
        Circle(1.0, 0.5, 1.0),
        Circle(-1.0, 0.5, 1.0),
    ]
    ds = DiskStabbingDS(circles)
    ds.build()
    visualize(ds, "slab0.png", slab_index=0)

    print(ds.query(0.5, 0.2))   # disk ids containing point
    print(ds.query(10.0, 0.0))  # []
    visualize(ds, "query.png", query=(2.0, 1.0))









import unittest
import random
from math import isfinite


def brute_force(circles, xq, yq):
    out = []
    for i, c in enumerate(circles):
        dx = xq - c.cx
        dy = yq - c.cy
        if dx*dx + dy*dy < c.r*c.r:
            out.append(i)
    return out


def mk_ds(circles):
    ds = DiskStabbingDS(circles)
    ds.build()
    return ds


class TestDiskStabbingDS(unittest.TestCase):
    # ---------- basic sanity ----------
    def test_01_empty(self):
        ds = mk_ds([])
        self.assertEqual(ds.query(0.0, 0.0), [])

    def test_02_single_inside(self):
        circles = [Circle(0.0, 0.0, 2.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(1.0, 0.0), [0])

    def test_03_single_outside(self):
        circles = [Circle(0.0, 0.0, 2.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(3.0, 0.0), [])

    def test_04_single_center(self):
        circles = [Circle(5.0, -7.0, 3.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(5.0, -7.0), [0])

    # ---------- multiple circles, simple layouts ----------
    def test_05_two_disjoint(self):
        circles = [Circle(-10.0, 0.0, 1.0), Circle(10.0, 0.0, 1.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(-10.0, 0.0), [0])
        self.assertEqual(ds.query(10.0, 0.0), [1])
        self.assertEqual(ds.query(0.0, 0.0), [])

    def test_06_two_overlapping_point_in_both(self):
        circles = [Circle(0.0, 0.0, 2.0), Circle(1.0, 0.0, 2.0)]
        ds = mk_ds(circles)
        got = ds.query(0.5, 0.0)
        self.assertEqual(got, [0, 1])

    def test_07_nested_circles(self):
        circles = [Circle(0.0, 0.0, 5.0), Circle(0.0, 0.0, 1.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(0.5, 0.0), [0, 1])
        self.assertEqual(ds.query(3.0, 0.0), [0])

    def test_08_many_same_center_different_radii(self):
        circles = [Circle(0.0, 0.0, r) for r in [0.5, 1.0, 2.0, 4.0, 8.0]]
        ds = mk_ds(circles)
        got = ds.query(1.5, 0.0)
        self.assertEqual(got, [2, 3, 4])

    def test_09_negative_coordinates(self):
        circles = [Circle(-3.0, -4.0, 2.0), Circle(-6.0, -8.0, 1.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(-3.0, -4.0), [0])
        self.assertEqual(ds.query(-6.0, -8.0), [1])
        self.assertEqual(ds.query(-5.0, -5.0), [])

    # ---------- big/small magnitudes ----------
    def test_10_huge_radius(self):
        circles = [Circle(0.0, 0.0, 1e6)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(12345.0, -54321.0), [0])

    def test_11_tiny_radius(self):
        circles = [Circle(0.0, 0.0, 1e-6)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(0.0, 0.0), [0])
        self.assertEqual(ds.query(1e-3, 0.0), [])

    # ---------- query extremes ----------
    def test_12_query_far_x(self):
        circles = [Circle(0.0, 0.0, 2.0), Circle(10.0, 0.0, 2.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(-1e9, 0.0), [])
        self.assertEqual(ds.query(1e9, 0.0), [])

    def test_13_query_far_y(self):
        circles = [Circle(0.0, 0.0, 2.0)]
        ds = mk_ds(circles)
        self.assertEqual(ds.query(0.0, 1e9), [])
        self.assertEqual(ds.query(0.0, -1e9), [])

    # ---------- exact_filter behavior ----------
    def test_14_exact_filter_false_is_superset(self):
        circles = [Circle(0.0, 0.0, 2.0), Circle(10.0, 0.0, 2.0)]
        ds = mk_ds(circles)
        q = (0.0, 0.0)
        exact = set(ds.query(*q, exact_filter=True))
        approx = set(ds.query(*q, exact_filter=False))
        self.assertTrue(exact.issubset(approx))

    # ---------- determinism ----------
    def test_15_build_deterministic_results(self):
        circles = [Circle(0.0, 0.0, 2.0), Circle(1.0, 0.0, 2.0), Circle(-1.0, 0.5, 1.2)]
        ds1 = mk_ds(circles)
        ds2 = mk_ds(circles)
        queries = [(x/2.0, y/2.0) for x in range(-6, 7) for y in range(-6, 7)]
        for xq, yq in queries:
            self.assertEqual(ds1.query(xq, yq), ds2.query(xq, yq))

    # ---------- intersection-heavy, “crazy” hand-crafted ----------
    def test_16_three_way_overlap_zone(self):
        circles = [
            Circle(0.0, 0.0, 3.0),
            Circle(2.0, 0.0, 3.0),
            Circle(1.0, 1.732, 3.0),  # roughly equilateral triangle top
        ]
        ds = mk_ds(circles)
        # near the center where all should overlap
        got = ds.query(1.0, 0.6)
        self.assertEqual(got, [0, 1, 2])

    def test_17_many_intersections_ring(self):
        circles = [Circle(0.0, 0.0, 5.0)]
        # small circles around it
        for k in range(8):
            ang = k * 0.78539816339  # ~pi/4
            circles.append(Circle(3.0 * (k % 2 - 0.5), 3.0 * ((k // 2) % 2 - 0.5), 3.0))
        ds = mk_ds(circles)
        # brute-check a few points
        for (xq, yq) in [(0.0, 0.0), (4.0, 0.0), (-4.0, 0.0), (0.0, 4.0), (2.0, 2.0)]:
            self.assertEqual(ds.query(xq, yq), brute_force(circles, xq, yq))

    def test_18_many_concentric_plus_offset(self):
        circles = [Circle(0.0, 0.0, r) for r in [1, 2, 3, 4, 5, 6]]
        circles += [Circle(3.0, 0.0, 2.5), Circle(-3.0, 0.0, 2.5)]
        ds = mk_ds(circles)
        visualize(ds, "query18_2.png", query=(-3.1, 0.1))
        visualize(ds, "slab18.png", slab_index=0)
        for (xq, yq) in [(0.1, 0.1), (3.1, 0.0), (-3.1, 0.1), (5.1, 0.1), (2.1, 1.1)]:
            self.assertEqual(ds.query(xq, yq), brute_force(circles, xq, yq))

    # ---------- randomized property tests ----------
    def test_19_random_small_many_queries(self):
        rng = random.Random(0)
        for _trial in range(30):
            n = 8
            circles = []
            for i in range(n):
                cx = rng.uniform(-5, 5)
                cy = rng.uniform(-5, 5)
                r = rng.uniform(0.5, 4.0)
                circles.append(Circle(cx, cy, r))
            ds = mk_ds(circles)

            for _q in range(200):
                xq = rng.uniform(-8, 8)
                yq = rng.uniform(-8, 8)
                got = ds.query(xq, yq)
                exp = brute_force(circles, xq, yq)
                self.assertEqual(got, exp)

    def test_20_random_medium_more_circles(self):
        rng = random.Random(1)
        circles = []
        n = 25
        for i in range(n):
            cx = rng.uniform(-20, 20)
            cy = rng.uniform(-20, 20)
            r = rng.uniform(1.0, 8.0)
            circles.append(Circle(cx, cy, r))

        ds = mk_ds(circles)

        for _q in range(1000):
            xq = rng.uniform(-25, 25)
            yq = rng.uniform(-25, 25)
            got = ds.query(xq, yq)
            exp = brute_force(circles, xq, yq)
            self.assertEqual(got, exp)

    def test_21_random_grid_queries(self):
        rng = random.Random(2)
        circles = []
        for i in range(15):
            circles.append(Circle(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(0.8, 6.0)))
        ds = mk_ds(circles)

        for xi in range(-20, 21):
            for yi in range(-20, 21):
                xq = xi * 0.5
                yq = yi * 0.5
                got = ds.query(xq, yq)
                exp = brute_force(circles, xq, yq)
                self.assertEqual(got, exp)

    # ---------- robustness-ish within your “ignore edge cases” stance ----------
    def test_22_no_nan_internals_on_queries(self):
        circles = [Circle(0.0, 0.0, 2.0), Circle(1.0, 0.5, 3.0)]
        ds = mk_ds(circles)
        for (xq, yq) in [(-100.0, 0.0), (0.0, 0.0), (1.0, 100.0), (2.0, -100.0)]:
            res = ds.query(xq, yq)
            self.assertTrue(all(isinstance(i, int) for i in res))

    def test_23_many_identical_circles(self):
        circles = [Circle(1.0, 2.0, 3.0) for _ in range(10)]
        ds = mk_ds(circles)
        got = ds.query(1.0, 2.0)
        self.assertEqual(got, list(range(10)))

    def test_24_line_of_circles(self):
        circles = [Circle(float(i), 0.0, 1.1) for i in range(-10, 11)]
        ds = mk_ds(circles)
        for xq in [i * 0.5 for i in range(-40, 41)]:
            got = ds.query(xq, 0.0)
            exp = brute_force(circles, xq, 0.0)
            self.assertEqual(got, exp)
    def test_25_dynamic_eval_used_at_each_internal_node(self):
        # 4 concentric circles => 8 endpoints in the central slab (perfect segtree)
        circles = [Circle(0.0, 0.0, r) for r in (1.0, 2.0, 3.0, 4.0)]
        ds = mk_ds(circles)

        # Pick x strictly inside all circles' x-ranges so all 4 are active in the slab
        xq, yq = 0.1, 0.0

        # Find the slab used for this query
        j = bisect_right(ds._xs, xq) - 1
        self.assertGreaterEqual(j, 0)
        slab = ds._slabs[j]

        # Ensure we really have 8 endpoints so the expected eval-count is deterministic
        self.assertIsNotNone(slab.root)
        self.assertEqual(len(slab.order), 8, "Test expects 4 active circles => 8 endpoints in slab")

        # Monkeypatch EndpointDesc.eval to count calls during query descent
        orig_eval = EndpointDesc.eval
        calls = {"n": 0}

        def counted_eval(self, circles, x):
            calls["n"] += 1
            return orig_eval(self, circles, x)

        EndpointDesc.eval = counted_eval
        try:
            # exact_filter=False prevents extra distance checks, isolating segtree traversal behavior
            _ = ds.query(xq, yq, exact_filter=False)
        finally:
            EndpointDesc.eval = orig_eval

        # For m=8 endpoints, build_rank_segtree makes a perfect tree of depth 4.
        # Your seg_stab_query evaluates split at every INTERNAL node only => depth-1 = 3 eval calls.
        self.assertEqual(
            calls["n"], 3,
            f"Expected 3 dynamic split evaluations for m=8 endpoints; got {calls['n']}."
        )


if __name__ == "__main__":
    unittest.main()









