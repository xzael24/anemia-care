# -*- coding: utf-8 -*-
"""Validasi baselines_colab.ipynb: JSON valid + tiap code cell lolos compile()."""
import json
import sys
from pathlib import Path

NB = Path(r"scripts/training/baselines_colab.ipynb")
nb = json.loads(NB.read_text(encoding="utf-8"))
print(f"nbformat {nb['nbformat']}.{nb['nbformat_minor']} | sel: {len(nb['cells'])}")

n_code = n_md = 0
for i, c in enumerate(nb["cells"]):
    src = "".join(c["source"])
    if c["cell_type"] == "markdown":
        n_md += 1
        continue
    n_code += 1
    lines = [ln for ln in src.splitlines() if not ln.lstrip().startswith(("%", "!"))]
    try:
        compile("\n".join(lines), f"<cell {i}>", "exec")
    except SyntaxError as e:
        print(f"  SYNTAX ERROR cell {i}: {e}")
        sys.exit(1)

print(f"code: {n_code} sel | markdown: {n_md} sel | semua lolos compile -> OK")