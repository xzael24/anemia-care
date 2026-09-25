"""Preview annotated + statistik nail-vs-skin yang aman (guard empty boxes)."""
import json
from pathlib import Path

import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest")
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(META)
ids = [288, 14, 54, 47, 1, 100, 110]
sel = df[df.PATIENT_ID.isin(ids)]


def valid(boxes, h, w):
    out = []
    for (x1, y1, x2, y2) in boxes:
        x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
        if x1 < 0 or y1 < 0 or x2 >= w or y2 >= h or x2 <= x1 or y2 <= y1:
            continue
        out.append((x1, y1, x2, y2))
    return out


def stats(L, boxes):
    vals = [L[y1:y2 + 1, x1:x2 + 1] for (x1, y1, x2, y2) in boxes]
    if not vals:
        return None
    m = np.concatenate([v.ravel() for v in vals])
    return float(m.mean())


for _, r in sel.iterrows():
    img = cv2.imread(str(PHOTO / f"{r.PATIENT_ID}.jpg"))
    h, w = img.shape[:2]
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    L = lab[..., 0].astype(np.float32)
    nails = valid(json.loads(r.NAIL_BOUNDING_BOXES), h, w)
    skins = valid(json.loads(r.SKIN_BOUNDING_BOXES), h, w)
    nl, sl = stats(L, nails), stats(L, skins)
    print(f"{r.PATIENT_ID}: nail_L={nl:.1f} skin_L={sl if sl is None else round(sl,1)} hb={r.HB_LEVEL_GperL} "
          f"n_nail={len(nails)} n_skin={len(skins)}")
    ann = img.copy()
    for (x1, y1, x2, y2) in nails:
        cv2.rectangle(ann, (x1, y1), (x2, y2), (0, 255, 0), 2)
    for (x1, y1, x2, y2) in skins:
        cv2.rectangle(ann, (x1, y1), (x2, y2), (255, 0, 0), 2)
    cv2.imwrite(str(OUT / f"annot_{r.PATIENT_ID}.png"), ann)