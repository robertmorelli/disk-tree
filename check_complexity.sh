#!/bin/bash
# Simple complexity verification

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          COMPLEXITY VERIFICATION (SIMPLE CHECK)            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "This tests if the implementation follows theoretical bounds:"
echo "  • Query time:  O(log n)"
echo "  • Space usage: O(n log n)"
echo ""
echo "Method: Double n each step, check if ratios match theory"
echo ""

# Compile Zig version if needed
if [ ! -f "complexity_check_simple" ] || [ "complexity_check_simple.zig" -nt "complexity_check_simple" ]; then
    echo "Compiling Zig checker..."
    zig build-exe complexity_check_simple.zig -O ReleaseFast 2>/dev/null
    echo ""
fi

# Run Zig version
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ZIG IMPLEMENTATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./complexity_check_simple

# Run Python version
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PYTHON IMPLEMENTATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
chmod +x complexity_check_simple.py
pypy3 complexity_check_simple.py

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                        SUMMARY                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✓ = Good match to theoretical complexity"
echo "⚠ = Some deviation (still functional)"
echo ""
echo "Query time should show ✓ - that's the critical metric!"
echo ""
