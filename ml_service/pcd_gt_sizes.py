"""Check GT box sizes + improve PCD heuristic: grow detected blobs to expected nail size."""
import json
from pathlib import Path
import numpy as np
import pandas as pd

META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
df = pd.read_csv(META)

widths, heights = [], []
for _, row in df.iterrows():
    try:
        nails = json.loads(row.NAIL_BOUNDING_BOXES)
    except Exception:
        continue
    for b in nails:
        (u1, v1), (u2, v2) = b[:2], b[2:]
        w = abs(u2 - u1)
        h = abs(v2 - v1)
        widths.append(w)
        heights.append(h)

w, h = np.array(widths), np.array(heights)
print(f"GT box sizes (original landscape coords, {len(w)} boxes):")
print(f"  Width:  mean {w.mean():.0f}, median {np.median(w):.0f}, min {w.min()}, max {w.max()}")
print(f"  Height: mean {h.mean():.0f}, median {np.median(h):.0f}, min {h.min()}, max {h.max()}")
print(f"  Aspect (w/h): mean {(w/h).mean():.2f}, median {np.median(w/h):.2f}")

# After H6 transform: x = 600-u, y = v → in portrait coords
# nail box w' = |600-u2 - (600-u1)| = |u1-u2| = w (same!)
# nail box h' = |v2-v1| = h (same!)
# So transformed nail boxes have same width/height as original.
print(f"\nSummary: GT nail boxes in portrait are typically ~{np.median(w):.0f}×{np.median(h):.0f} px")
print(f"  25th-75th pctl: width {np.percentile(w,25):.0f}-{np.percentile(w,75):.0f}, "
      f"height {np.percentile(h,25):.0f}-{np.percentile(h,75):.0f}")
