"""Overlay langsung: bbox GT di beberapa kandidat scale — cari yang nempel di kuku."""
import json
from pathlib import Path

import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\scale_probe")
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(META)
scales = [0.6, 0.7, 0.8, 1.0]
colors = {0.6: (0, 0, 255), 0.7: (0, 255, 0), 0.8: (255, 0, 0), 1.0: (0, 255, 255)}

for pid in [288, 54, 47]:
    r = df[df.PATIENT_ID == pid].iloc[0]
    img = cv2.imread(str(PHOTO / f"{pid}.jpg"))
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    for s in scales:
        for (x1, y1, x2, y2) in nails:
            a = tuple(int(v * s) for v in (x1, y1, x2, y2))
            cv2.rectangle(img, (a[0], a[1]), (a[2], a[3]), colors[s], 2)
        lab = f"s={s}"
        cv2.putText(img, lab, (10, int(20 + 20 * scales.index(s))), cv2.FONT_HERSHEY_SIMPLEX,
                    0.5, colors[s], 1, cv2.LINE_AA)
    cv2.imwrite(str(OUT / f"{pid}_scale.png"), img)
    print("saved", pid)