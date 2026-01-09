# Disk Tree Construction Algorithm: O(i·n·log(i·n)) Complexity

## Overview

The disk tree construction uses a **persistent segment tree** with **slab segregation** based on disk intersections. The key insight is that we only need to check adjacent disk arcs (left and right neighbors) to efficiently find all intersections using a sweep line algorithm.

## Time Complexity Analysis

For `n` circles with `i` total intersections:
- **Construction time**: O(i·n·log(i·n))
- **Query time**: O(log n)
- **Space**: O(i·n)

### Why This Complexity?

1. **Intersection Detection**: O(i·log n) using sweep line with priority queue
   - Each of n circles generates at most 2 events (enter/exit)
   - At each event, we only check adjacent arcs in the active set
   - Total intersections found: i
   - Each check is O(log n) for balanced tree operations

2. **Persistent Segment Tree Construction**: O(i·n·log n)
   - We create one version of the tree per intersection point
   - Each version requires O(n) work to determine which disks are active
   - Tree update/copy is O(log n)
   - Total: i versions × n disks × log n

3. **Overall**: O(i·log n + i·n·log n) = O(i·n·log n)

## Performance Targets

For 100,000 circles with reasonable intersection density:

| Metric | Target | Expected i |
|--------|--------|------------|
| Build Time | < 1 second | < 10,000 intersections |
| Query Time | < 1 ms | any |
| Memory | reasonable | < 1 GB |

### Intersection Density Assumptions

- Sparse case (i ≈ n): ~100k intersections → ~100ms build time
- Moderate case (i ≈ 10n): ~1M intersections → ~1s build time
- Dense case (i ≈ n²): not practical for n=100k (would need optimization)

## Algorithm Details

### Phase 1: Sweep Line Intersection Detection

**Key Insight**: At any vertical line x=c, the active circles form a vertically ordered set. Only adjacent circles in this ordering can intersect.

```
Algorithm: FindAllIntersections(circles)
Input: n circles with (x, y, r)
Output: sorted list of intersection x-coordinates

1. Create events for each circle:
   - ENTER event at x = center.x - radius
   - EXIT event at x = center.x + radius

2. Sort events by x-coordinate: O(n log n)

3. Initialize:
   - active_arcs = balanced tree (ordered by y-position at current x)
   - intersections = priority queue (ordered by x-coordinate)
   - processed = set of circle pairs already checked

4. Sweep through events:
   For each event at x-coordinate:

   a. Process all intersections at or before this x
   b. If ENTER event for circle C:
      - Find position in active_arcs by y-coordinate
      - Check intersection with neighbor above (if exists)
      - Check intersection with neighbor below (if exists)
      - Add C to active_arcs
      - Update neighbors to check their new neighbors

   c. If EXIT event for circle C:
      - Remove C from active_arcs
      - Check if former neighbors now intersect

5. Return all intersection x-coordinates sorted
```

**Why Only Adjacent Arcs?**

At a vertical line x=c, circles are ordered by their y-intersection with this line. If circle A is above circle B, and they don't intersect, then A cannot intersect any circle below B at this x-coordinate. This is because:
- Circles are convex
- The vertical ordering is consistent within each x-slice
- Non-adjacent circles are separated by the circles between them

### Phase 2: Slab Segregation

```
Algorithm: CreateSlabs(intersections)
Input: sorted intersection x-coordinates [x₀, x₁, ..., xᵢ]
Output: i+1 slabs

For each pair of consecutive intersections (xⱼ, xⱼ₊₁):
  Create slab j:
    - left boundary: xⱼ
    - right boundary: xⱼ₊₁
    - sample point: (xⱼ + xⱼ₊₁) / 2
```

**Property**: Within each slab, the set of circles covering any vertical line is constant.

### Phase 3: Persistent Segment Tree Construction

```
Algorithm: BuildPersistentTree(circles, slabs)
Input: n circles, i+1 slabs
Output: persistent segment tree with i+1 versions

1. Build base segment tree over y-coordinate range: O(n log n)

2. For each slab s at x = sample_point:
   a. Determine active circles: {C | C contains point (x, y) for some y}
      - A circle (cx, cy, r) is active if |cx - x| < r

   b. Create new tree version by copying previous version: O(log n)

   c. For each circle that changed state (became active or inactive):
      - Update tree by modifying O(log n) nodes
      - Each node stores: count of active circles covering its interval

   d. Store tree version with slab bounds
```

**Persistence Optimization**: Use path copying instead of full tree copying.
- Only O(log n) nodes change between versions
- Share unchanged subtrees between versions
- Each version only requires O(log n) new nodes

### Phase 4: Query

```
Algorithm: Query(tree, point)
Input: point (x, y)
Output: deepest disk containing point

1. Binary search for slab containing x: O(log i)

2. Use corresponding tree version: O(1)

3. Query segment tree at y-coordinate: O(log n)
   - Returns count of disks at this point

4. Walk down tree to find deepest disk: O(log n)
```

## Optimization Techniques

### 1. Efficient Active Arc Management

Use a balanced binary search tree (e.g., Red-Black tree) to maintain active arcs:
- **Key**: y-coordinate where arc crosses current sweep line x
- **Value**: circle information
- **Operations**: insert O(log n), delete O(log n), find neighbors O(log n)

### 2. Intersection Caching

```
When checking circles A and B:
- Compute hash = (min(A.id, B.id), max(A.id, B.id))
- If hash in processed_set: skip
- Else: compute intersection, add hash to processed_set
```

This prevents checking the same pair multiple times.

### 3. Memory-Efficient Persistent Trees

Instead of storing full trees, use:
- **Path copying**: Only copy nodes on path from root to modified leaf
- **Node pooling**: Reuse freed nodes
- **Pointer sharing**: Multiple versions share unchanged subtrees

### 4. Cache-Friendly Data Layout

```
Struct Node {
    left, right: *Node     // 16 bytes
    y_min, y_max: f64      // 16 bytes
    count: u32             // 4 bytes
    deepest: u32           // 4 bytes (circle ID)
    padding: 8 bytes       // total: 48 bytes (cache-line friendly)
}
```

### 5. SIMD for Distance Computations

When finding active circles in a slab:
```zig
// Process 4 circles at once
for (circles[0..n step 4]) |quad| {
    dx = _mm256_sub_pd(cx_vector, sample_x);
    active_mask = _mm256_cmp_pd(abs(dx), radius_vector, _CMP_LT_OQ);
    // Extract active circles
}
```

## Expected Performance

### 100k Circles with 10k Intersections

1. **Intersection Detection**:
   - Events: 200k → 200k log 200k ≈ 3.5M ops
   - Intersection checks: ~20k (only adjacencies)
   - Priority queue ops: 10k log 10k ≈ 130k ops
   - **Total**: ~5M ops ≈ 10ms @ 500M ops/sec

2. **Active Circle Determination**:
   - Per slab: 100k distance checks (SIMD → 25k ops)
   - 10k slabs × 25k ops = 250M ops ≈ 500ms

3. **Tree Construction**:
   - Base tree: 100k log 100k ≈ 1.7M ops ≈ 3ms
   - 10k versions × log 100k × changes ≈ 2M ops ≈ 4ms
   - **Total**: ~7ms

4. **Total Build Time**: 10ms + 500ms + 7ms ≈ **517ms** ✓

5. **Query Time**:
   - Binary search slabs: log 10k ≈ 13 comparisons
   - Segment tree query: log 100k ≈ 17 node visits
   - **Total**: ~30 comparisons ≈ **0.1 μs** ✓

## Implementation Checklist

- [ ] Sweep line with balanced tree for active arcs
- [ ] Priority queue for intersection events
- [ ] Efficient circle-circle intersection computation
- [ ] Persistent segment tree with path copying
- [ ] Memory pooling for tree nodes
- [ ] SIMD for batch distance computations
- [ ] Cache-aligned data structures
- [ ] Proper benchmarking with realistic data

## Theoretical Limits

**Best Case**: Circles don't intersect (i = 0)
- Build time: O(n log n) for sorting
- Single tree version needed
- 100k circles → ~3ms

**Worst Case**: All circles intersect (i = n²)
- Not practical for large n
- Would need spatial hashing or R-tree pre-filtering
- For n=100k, would be ~10 billion intersections

**Practical Case**: Moderate intersection (i = O(n))
- Build time: O(n² log n) - still manageable
- 100k circles → sub-second build time achievable
