#!/bin/bash
# Head-to-head comparison: Zig vs Python

set -e

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                   ZIG vs PYTHON: ULTIMATE SHOWDOWN                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Generate test data if needed
if [ ! -f "test_data.json" ]; then
    echo "[1/3] Generating portable test data..."
    python3 generate_test_data.py
    echo ""
else
    echo "[1/3] Test data already exists (test_data.json)"
    echo ""
fi

# Run Python tests
echo "[2/3] Running Python stress tests (PyPy)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
pypy3 stress_test_python.py > python_results.txt 2>&1
cat python_results.txt
echo ""

# Run Zig tests
echo "[3/3] Running Zig stress tests (ReleaseFast)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ! -f "stress_tests" ]; then
    zig build-exe stress_tests.zig -O ReleaseFast 2>/dev/null
fi
./stress_tests > zig_results.txt 2>&1
cat zig_results.txt
echo ""

# Parse and compare results
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                              COMPARISON ANALYSIS                               ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Extract totals (this is a simple grep, could be more sophisticated)
PYTHON_BUILD=$(grep "Total build time:" python_results.txt | awk '{print $4}')
PYTHON_QUERY=$(grep "Total query time:" python_results.txt | awk '{print $4}')
PYTHON_TOTAL=$(grep "Total time:" python_results.txt | tail -1 | awk '{print $3}')

ZIG_BUILD=$(grep "Total build time:" zig_results.txt | awk '{print $4}')
ZIG_QUERY=$(grep "Total query time:" zig_results.txt | awk '{print $4}')
ZIG_TOTAL=$(grep "Total time:" zig_results.txt | tail -1 | awk '{print $3}')

echo "Implementation    Build Time    Query Time    Total Time"
echo "───────────────────────────────────────────────────────────"
printf "Python (PyPy)     %10s ms  %10s ms  %10s ms\n" "$PYTHON_BUILD" "$PYTHON_QUERY" "$PYTHON_TOTAL"
printf "Zig (Release)     %10s ms  %10s ms  %10s ms\n" "$ZIG_BUILD" "$ZIG_QUERY" "$ZIG_TOTAL"
echo "───────────────────────────────────────────────────────────"

# Calculate speedups (using bc for floating point)
BUILD_SPEEDUP=$(echo "scale=2; $PYTHON_BUILD / $ZIG_BUILD" | bc)
QUERY_SPEEDUP=$(echo "scale=2; $PYTHON_QUERY / $ZIG_QUERY" | bc)
TOTAL_SPEEDUP=$(echo "scale=2; $PYTHON_TOTAL / $ZIG_TOTAL" | bc)

printf "Zig Speedup       %10sx       %10sx       %10sx\n" "$BUILD_SPEEDUP" "$QUERY_SPEEDUP" "$TOTAL_SPEEDUP"
echo ""

# Winner announcement
echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                                   WINNER                                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""

if (( $(echo "$TOTAL_SPEEDUP > 1.5" | bc -l) )); then
    echo "  🏆 ZIG DOMINATES with ${TOTAL_SPEEDUP}x total speedup!"
    echo ""
    echo "  Zig is faster at:"
    echo "    - Building: ${BUILD_SPEEDUP}x"
    echo "    - Queries:  ${QUERY_SPEEDUP}x"
    echo ""
    echo "  The wall has been OBLITERATED. 💥"
else
    echo "  Both implementations perform well!"
    echo "  Zig has ${TOTAL_SPEEDUP}x speedup."
fi

echo ""
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Cleanup
rm -f python_results.txt zig_results.txt
