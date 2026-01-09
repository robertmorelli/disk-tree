#!/usr/bin/env pypy3
"""Run disk_tree tests without matplotlib dependency"""

import sys
import os

# Read disk_tree.py and remove matplotlib parts
with open('disk_tree.py', 'r') as f:
    code = f.read()

# Remove matplotlib import and visualization functions
lines = code.split('\n')
filtered_lines = []
skip_until_next_def = False

for i, line in enumerate(lines):
    # Skip matplotlib import
    if 'import matplotlib' in line:
        continue

    # Skip visualization functions
    if line.startswith('def visualize(') or line.startswith('def collect_segtree_path(') or line.startswith('def iter_segnodes(') or line.startswith('def choose_slab('):
        skip_until_next_def = True
        continue

    # End skip when we hit the next class or major section
    if skip_until_next_def:
        if (line.startswith('class ') or
            line.startswith('# ---') or
            (line.startswith('def ') and 'def test_' not in line and 'def brute' not in line and 'def mk_ds' not in line)):
            skip_until_next_def = False
        else:
            continue

    filtered_lines.append(line)

code = '\n'.join(filtered_lines)

# Remove calls to visualize in main and tests
code = code.replace('visualize(ds, "slab0.png", slab_index=0)', '# visualize removed')
code = code.replace('visualize(ds, "query.png", query=(2.0, 1.0))', '# visualize removed')
code = code.replace('visualize(ds, "query18_2.png", query=(-3.1, 0.1))', '# visualize removed')
code = code.replace('visualize(ds, "slab18.png", slab_index=0)', '# visualize removed')

# Execute the modified code
exec(code)
