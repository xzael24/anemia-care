"""Visual check of H6 (horizontal flip in portrait coords: (x,y)=(600-u, v))
plus small scale / y-translate variants — do the GT nail boxes land ON the nails?"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\scale_probe")

df = pd.read_csv(META)

def h6_scale(u, v, s=1.0, dy=0.0):
    """horizontal mirror in portrait, optional scale about center column 300, + y shift"""
    x = 300 + (300 - u) * s
    y = v + dy
    return (x, y)

PIDS = [288, 54, 47, 200, 100, 50]
VARIANTS = [
    ("H6 s1.0",         dict(s=1.0, dy=0)),
    ("H6 s1.14",        dict(s=1.14, dy=0)),
    ("H6 s1.0 dy+40",   dict(s=1.0, dy=40)),
    ("H6 s1.0 dy+80",   dict(s=1.0, dy=80)),
]
COLORS = [(0,0,255), (0,255,255), (255,0,255), (0,255,0)]

for pid in PIDS:
    rows = df[df.PATIENT_ID == pid]
    if rows.empty:
        continue
    r = rows.iloc[0]
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        continue
    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    H, W = img_rot.shape[:2]
    nails = json.loads(r.NAIL_BOUNDING_BOXES)

    panel = img_rot.copy()
    for (u1, v1, u2, v2) in nails:
        for (label, kw) in VARIANTS:
            idx = VARIANTS.index((label, kw))
            c = COLORS[idx]
            corners = [(u1,v1),(u2,v1),(u1,v2),(u2,v2)]
            nc = [h6_scale(x, y, **kw) for (x, y) in corners]
            xs = [p[0] for p in nc]; ys = [p[1] for p in nc]
            tx1, ty1, tx2, ty2 = int(min(xs)), int(min(ys)), int(max(xs)), int(max(ys))
            cv2.rectangle(panel, (tx1,ty1), (tx2,ty2), c, 2)
    cv2.putText(panel, f"pid {pid} H6 variants | red=1.0 yellow=1.14 magenta=1.0+40 green=1.0+80",
                (10, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255,255,255), 2)
    out_path = OUT / f"{pid}_h6_variants.png"
    cv2.imwrite(str(out_path), panel)
    print(f"Saved {out_path}")
print("done")