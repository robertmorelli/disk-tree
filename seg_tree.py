class Node:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

class PersistentSegTree:
    def __init__(self, min_val=0, max_val=10**9):
        self.root = Node()
        self.min_val = min_val
        self.max_val = max_val
    
    def update(self, idx, val):
        """Update position idx to value val, returns new root"""
        new_root = self._update(self.root, self.min_val, self.max_val, idx, val)
        return PersistentSegTree._from_root(new_root, self.min_val, self.max_val)
    
    @staticmethod
    def _from_root(root, min_val, max_val):
        """Create a new tree from an existing root"""
        tree = PersistentSegTree.__new__(PersistentSegTree)
        tree.root = root
        tree.min_val = min_val
        tree.max_val = max_val
        return tree
    
    def _update(self, node, left, right, idx, val):
        if left == right:
            return Node(val)
        
        mid = (left + right) // 2
        if idx <= mid:
            old_left = node.left if node else None
            new_left = self._update(old_left, left, mid, idx, val)
            new_right = node.right if node else None
        else:
            new_left = node.left if node else None
            old_right = node.right if node else None
            new_right = self._update(old_right, mid + 1, right, idx, val)
        
        left_val = new_left.val if new_left else 0
        right_val = new_right.val if new_right else 0
        return Node(left_val + right_val, new_left, new_right)
    
    def query(self, l, r):
        """Query sum in range [l, r]"""
        return self._query(self.root, self.min_val, self.max_val, l, r)
    
    def _query(self, node, left, right, ql, qr):
        if not node or qr < left or ql > right:
            return 0
        
        if ql <= left and right <= qr:
            return node.val
        
        mid = (left + right) // 2
        return (self._query(node.left, left, mid, ql, qr) + 
                self._query(node.right, mid + 1, right, ql, qr))


# ============== TESTS ==============

def test_basic_operations():
    """Test basic update and query operations"""
    st = PersistentSegTree(0, 100)
    
    # Test single update and query
    st = st.update(5, 10)
    assert st.query(5, 5) == 10, "Single element query failed"
    assert st.query(0, 10) == 10, "Range query failed"
    
    # Test multiple updates
    st = st.update(10, 20)
    assert st.query(5, 5) == 10, "First update changed"
    assert st.query(10, 10) == 20, "Second update failed"
    assert st.query(5, 10) == 30, "Range sum incorrect"
    
    print("✓ Basic operations test passed")


def test_overwrite():
    """Test overwriting values"""
    st = PersistentSegTree(0, 100)
    
    st = st.update(5, 10)
    assert st.query(5, 5) == 10
    
    st = st.update(5, 25)
    assert st.query(5, 5) == 25, "Overwrite failed"
    assert st.query(0, 10) == 25, "Range after overwrite incorrect"
    
    print("✓ Overwrite test passed")


def test_large_range():
    """Test with large coordinate range"""
    st = PersistentSegTree(0, 10**9)
    
    st = st.update(1000000, 5)
    st = st.update(999999999, 15)
    
    assert st.query(1000000, 1000000) == 5
    assert st.query(999999999, 999999999) == 15
    assert st.query(1000000, 999999999) == 20
    assert st.query(0, 10**9) == 20
    
    print("✓ Large range test passed")


def test_empty_queries():
    """Test queries on empty ranges"""
    st = PersistentSegTree(0, 100)
    
    assert st.query(0, 100) == 0, "Empty tree should return 0"
    
    st = st.update(50, 10)
    assert st.query(0, 49) == 0, "Query before update should be 0"
    assert st.query(51, 100) == 0, "Query after update should be 0"
    
    print("✓ Empty queries test passed")


def test_consecutive_updates():
    """Test consecutive positions"""
    st = PersistentSegTree(0, 100)
    
    for i in range(10):
        st = st.update(i, i + 1)
    
    # Check individual values
    for i in range(10):
        assert st.query(i, i) == i + 1, f"Value at {i} incorrect"
    
    # Check range sum: 1+2+3+...+10 = 55
    assert st.query(0, 9) == 55, "Consecutive range sum incorrect"
    
    print("✓ Consecutive updates test passed")


def test_sparse_updates():
    """Test sparse updates across large range"""
    st = PersistentSegTree(0, 10**6)
    
    positions = [0, 100, 1000, 10000, 100000, 1000000]
    for pos in positions:
        st = st.update(pos, pos)
    
    for pos in positions:
        assert st.query(pos, pos) == pos, f"Sparse update at {pos} failed"
    
    # Query entire range
    expected = sum(positions)
    assert st.query(0, 10**6) == expected, "Total sum incorrect"
    
    print("✓ Sparse updates test passed")


def test_partial_ranges():
    """Test various partial range queries"""
    st = PersistentSegTree(0, 100)
    
    # Setup: positions 10, 20, 30, 40, 50 with values 1, 2, 3, 4, 5
    for i in range(5):
        st = st.update(10 * (i + 1), i + 1)
    
    assert st.query(10, 30) == 6, "Range [10,30] should be 1+2+3=6"
    assert st.query(20, 40) == 9, "Range [20,40] should be 2+3+4=9"
    assert st.query(15, 35) == 5, "Range [15,35] should be 2+3=5"
    assert st.query(10, 50) == 15, "Range [10,50] should be 1+2+3+4+5=15"
    
    print("✓ Partial ranges test passed")


def test_zero_values():
    """Test setting values to zero"""
    st = PersistentSegTree(0, 100)
    
    st = st.update(10, 50)
    assert st.query(10, 10) == 50
    
    st = st.update(10, 0)
    assert st.query(10, 10) == 0, "Zero update failed"
    assert st.query(0, 100) == 0, "Range should be 0 after zeroing"
    
    print("✓ Zero values test passed")


def test_negative_values():
    """Test negative values (if supported)"""
    st = PersistentSegTree(0, 100)
    
    st = st.update(10, -5)
    st = st.update(20, 10)
    st = st.update(30, -3)
    
    assert st.query(10, 10) == -5
    assert st.query(10, 30) == 2, "Sum with negatives: -5+10-3=2"
    
    print("✓ Negative values test passed")


def test_boundary_conditions():
    """Test boundary conditions"""
    st = PersistentSegTree(0, 100)
    
    # Test at boundaries
    st = st.update(0, 1)
    st = st.update(100, 2)
    
    assert st.query(0, 0) == 1, "Left boundary failed"
    assert st.query(100, 100) == 2, "Right boundary failed"
    assert st.query(0, 100) == 3, "Full range failed"
    
    print("✓ Boundary conditions test passed")


def test_stress_random():
    """Stress test with random operations"""
    import random
    
    st = PersistentSegTree(0, 1000)
    arr = [0] * 1001  # Simulate with array
    
    random.seed(42)
    
    for _ in range(100):
        # Random update
        idx = random.randint(0, 1000)
        val = random.randint(-100, 100)
        st = st.update(idx, val)
        arr[idx] = val
        
        # Random query
        l = random.randint(0, 1000)
        r = random.randint(l, 1000)
        
        expected = sum(arr[l:r+1])
        result = st.query(l, r)
        assert result == expected, f"Mismatch at query [{l},{r}]: got {result}, expected {expected}"
    
    print("✓ Stress test passed")


def test_overlapping_updates():
    """Test multiple updates to overlapping ranges"""
    st = PersistentSegTree(0, 100)
    
    # Update same positions multiple times
    st = st.update(10, 5)
    st = st.update(10, 10)
    st = st.update(10, 15)
    assert st.query(10, 10) == 15, "Final update should prevail"
    
    # Update nearby positions
    st = st.update(11, 20)
    st = st.update(12, 30)
    assert st.query(10, 12) == 65, "Sum should be 15+20+30=65"
    
    print("✓ Overlapping updates test passed")


def test_single_point_queries():
    """Test many single point queries"""
    st = PersistentSegTree(0, 10000)
    
    # Set every 100th position
    for i in range(0, 10001, 100):
        st = st.update(i, i // 100)
    
    # Query each one
    for i in range(0, 10001, 100):
        assert st.query(i, i) == i // 100, f"Point query at {i} failed"
    
    print("✓ Single point queries test passed")


# ============== NEW PERSISTENCE TESTS ==============

def test_persistence_basic():
    """Test that old versions remain unchanged"""
    st1 = PersistentSegTree(0, 100)
    st1 = st1.update(10, 5)
    
    # Create a new version
    st2 = st1.update(20, 10)
    
    # Old version should be unchanged
    assert st1.query(10, 10) == 5, "Old version changed!"
    assert st1.query(20, 20) == 0, "Old version has new data!"
    assert st1.query(0, 100) == 5, "Old version total changed!"
    
    # New version should have both updates
    assert st2.query(10, 10) == 5, "New version missing old data"
    assert st2.query(20, 20) == 10, "New version missing new data"
    assert st2.query(0, 100) == 15, "New version total wrong"
    
    print("✓ Basic persistence test passed")


def test_persistence_branching():
    """Test branching versions"""
    st0 = PersistentSegTree(0, 100)
    st0 = st0.update(10, 10)
    
    # Branch 1
    st1 = st0.update(20, 20)
    st1 = st1.update(30, 30)
    
    # Branch 2
    st2 = st0.update(20, 100)
    st2 = st2.update(40, 40)
    
    # Check original is unchanged
    assert st0.query(0, 100) == 10
    
    # Check branch 1
    assert st1.query(0, 100) == 60  # 10 + 20 + 30
    assert st1.query(20, 20) == 20
    assert st1.query(30, 30) == 30
    assert st1.query(40, 40) == 0
    
    # Check branch 2
    assert st2.query(0, 100) == 150  # 10 + 100 + 40
    assert st2.query(20, 20) == 100
    assert st2.query(30, 30) == 0
    assert st2.query(40, 40) == 40
    
    print("✓ Branching persistence test passed")


def test_persistence_overwrite():
    """Test that overwriting in new version doesn't affect old"""
    st1 = PersistentSegTree(0, 100)
    st1 = st1.update(10, 100)
    st1 = st1.update(20, 200)
    
    # Create new version and overwrite
    st2 = st1.update(10, 999)
    
    # Old version should be unchanged
    assert st1.query(10, 10) == 100, "Old version overwritten!"
    assert st1.query(0, 100) == 300, "Old version total changed!"
    
    # New version should have new value
    assert st2.query(10, 10) == 999, "New version doesn't have new value"
    assert st2.query(0, 100) == 1199, "New version total wrong (999 + 200)"
    
    print("✓ Persistence overwrite test passed")


def test_persistence_many_versions():
    """Test creating many versions"""
    versions = []
    st = PersistentSegTree(0, 100)
    
    # Create 20 versions, each adding a value
    for i in range(20):
        st = st.update(i * 5, i)
        versions.append(st)
    
    # Check each version has correct history
    for v_idx, version in enumerate(versions):
        expected_sum = sum(range(v_idx + 1))
        actual_sum = version.query(0, 100)
        assert actual_sum == expected_sum, f"Version {v_idx} sum wrong: {actual_sum} != {expected_sum}"
        
        # Check individual values
        for i in range(v_idx + 1):
            assert version.query(i * 5, i * 5) == i, f"Version {v_idx} missing value at {i*5}"
    
    print("✓ Many versions test passed")


def test_persistence_interleaved_queries():
    """Test querying different versions in interleaved manner"""
    st0 = PersistentSegTree(0, 100)
    st1 = st0.update(10, 1)
    st2 = st1.update(20, 2)
    st3 = st2.update(30, 3)
    st4 = st3.update(40, 4)
    
    # Query in mixed order
    assert st4.query(0, 100) == 10  # 1+2+3+4
    assert st2.query(0, 100) == 3   # 1+2
    assert st3.query(0, 100) == 6   # 1+2+3
    assert st1.query(0, 100) == 1   # 1
    assert st0.query(0, 100) == 0   # empty
    assert st4.query(30, 40) == 7   # 3+4
    assert st2.query(30, 40) == 0   # nothing
    
    print("✓ Interleaved queries test passed")


def test_persistence_no_mutation():
    """Test that nodes are truly immutable"""
    st1 = PersistentSegTree(0, 100)
    st1 = st1.update(50, 100)
    
    # Get the root node
    root1 = st1.root
    root1_val = root1.val
    root1_id = id(root1)
    
    # Create new version
    st2 = st1.update(50, 200)
    root2 = st2.root
    
    # Old root should be unchanged
    assert root1.val == root1_val, "Old root value mutated!"
    assert id(st1.root) == root1_id, "Old root pointer changed!"
    
    # New root should be different object
    assert id(root2) != id(root1), "New root is same object as old!"
    assert root2.val != root1.val, "New root has same value as old!"
    
    print("✓ No mutation test passed")


def test_persistence_shared_structure():
    """Test that versions share unchanged structure"""
    st1 = PersistentSegTree(0, 1000)
    st1 = st1.update(100, 10)
    st1 = st1.update(200, 20)
    st1 = st1.update(300, 30)
    
    # Update only one position
    st2 = st1.update(400, 40)
    
    # Nodes that weren't on the update path should be shared
    # This is hard to test directly, but we can verify correctness
    assert st1.query(100, 300) == 60
    assert st2.query(100, 300) == 60
    assert st1.query(400, 400) == 0
    assert st2.query(400, 400) == 40
    
    print("✓ Shared structure test passed")


def test_persistence_complex_scenario():
    """Test complex persistence scenario"""
    # Start with base
    base = PersistentSegTree(0, 1000)
    base = base.update(100, 10)
    base = base.update(200, 20)
    base = base.update(300, 30)
    
    # Create multiple branches
    branch_a = base.update(400, 100)
    branch_a = branch_a.update(500, 200)
    
    branch_b = base.update(400, 1000)
    branch_b = branch_b.update(600, 2000)
    
    branch_c = base.update(700, 5000)
    
    # Create sub-branches
    sub_a1 = branch_a.update(800, 50)
    sub_a2 = branch_a.update(800, 75)
    
    # Verify base unchanged
    assert base.query(0, 1000) == 60
    
    # Verify branch_a
    assert branch_a.query(0, 1000) == 360  # 10+20+30+100+200
    
    # Verify branch_b
    assert branch_b.query(0, 1000) == 3060  # 10+20+30+1000+2000
    
    # Verify branch_c
    assert branch_c.query(0, 1000) == 5060  # 10+20+30+5000
    
    # Verify sub-branches
    assert sub_a1.query(0, 1000) == 410  # branch_a + 50
    assert sub_a2.query(0, 1000) == 435  # branch_a + 75
    
    # Verify branch_a still unchanged
    assert branch_a.query(0, 1000) == 360
    
    print("✓ Complex scenario test passed")


def test_log_n_node_creation():
    """Test that each update creates O(log n) new nodes"""
    st = PersistentSegTree(0, 2**20)  # Large range
    
    # Track nodes created
    def count_nodes(node):
        if not node:
            return 0
        return 1 + count_nodes(node.left) + count_nodes(node.right)
    
    st1 = st.update(100000, 10)
    nodes1 = count_nodes(st1.root)
    
    # Update a different position (not adjacent) to create full path
    st2 = st1.update(900000, 20)
    nodes2 = count_nodes(st2.root)
    
    # Second update should create roughly log n new nodes
    # For range 2^20, log n ≈ 20-21
    new_nodes = nodes2 - nodes1
    assert new_nodes <= 25, f"Too many nodes created: {new_nodes} (expected ~20)"
    assert new_nodes >= 15, f"Too few nodes created: {new_nodes} (expected ~20)"
    
    print(f"✓ Log n node creation test passed (created {new_nodes} nodes)")


def test_persistence_with_negatives():
    """Test persistence with negative values"""
    st1 = PersistentSegTree(0, 100)
    st1 = st1.update(10, 100)
    st1 = st1.update(20, -50)
    
    st2 = st1.update(30, -30)
    st3 = st1.update(20, 200)  # Overwrite the -50
    
    # Check st1
    assert st1.query(0, 100) == 50  # 100 - 50
    
    # Check st2
    assert st2.query(0, 100) == 20  # 100 - 50 - 30
    
    # Check st3
    assert st3.query(0, 100) == 300  # 100 + 200
    assert st3.query(20, 20) == 200
    
    # Check st1 unchanged
    assert st1.query(20, 20) == -50
    
    print("✓ Persistence with negatives test passed")


def run_all_tests():
    """Run all tests"""
    print("Running Persistent Dynamic Segment Tree Tests...\n")
    
    # Original tests
    test_basic_operations()
    test_overwrite()
    test_large_range()
    test_empty_queries()
    test_consecutive_updates()
    test_sparse_updates()
    test_partial_ranges()
    test_zero_values()
    test_negative_values()
    test_boundary_conditions()
    test_stress_random()
    test_overlapping_updates()
    test_single_point_queries()
    
    print("\n--- Persistence-Specific Tests ---\n")
    
    # New persistence tests
    test_persistence_basic()
    test_persistence_branching()
    test_persistence_overwrite()
    test_persistence_many_versions()
    test_persistence_interleaved_queries()
    test_persistence_no_mutation()
    test_persistence_shared_structure()
    test_persistence_complex_scenario()
    test_log_n_node_creation()
    test_persistence_with_negatives()
    
    print("\n" + "="*50)
    print("ALL TESTS PASSED! ✓")
    print("="*50)


if __name__ == "__main__":
    run_all_tests()
