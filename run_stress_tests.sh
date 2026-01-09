#!/bin/bash
# Run comprehensive stress tests

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                      COMPREHENSIVE STRESS TEST SUITE                           ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This will hammer the implementation with:"
echo "  - Up to 100,000 circles"
echo "  - Up to 100,000 queries per test"
echo "  - Dense overlapping scenarios"
echo "  - Pathological cases"
echo ""
echo "Estimated runtime: 1-3 minutes"
echo ""
read -p "Press ENTER to begin..."
echo ""

# Make sure it's compiled
if [ ! -f "stress_tests" ] || [ "stress_tests.zig" -nt "stress_tests" ]; then
    echo "Compiling stress tests..."
    zig build-exe stress_tests.zig -O ReleaseFast 2>/dev/null
    echo ""
fi

# Run tests
./stress_tests

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                         HOW TO VIEW RESULTS                                    ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "The benchmark report is shown above ☝️"
echo ""
echo "To compare against Python:"
echo "  ./compare_implementations.sh"
echo ""
echo "This will run both implementations on the same test data and show:"
echo "  - Side-by-side timing comparisons"
echo "  - Speedup factors"
echo "  - Memory usage"
echo "  - Detailed per-test breakdowns"
echo ""
