"""Analisis cepat: distribusi LAB di nail vs skin vs full (figshare) — basis desain PCD."""
import json
from pathlib import Path

import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")

df = pd.read_csv(META)
sample = df[df.PATIENT_ID.isin([288, 54, 14, 47, 1, 100, 110])]
for _, r in sample.iterrows():
    p = PHOTO / f"{r.PATIENT_ID}.jpg"
    img = cv2.imread(str(p))
    if img is None:
        print(r.PATIENT_ID, "GAGAL BACA"); continue
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    L, A, B = lab[..., 0].astype(np.float32), lab[..., 1].astype(np.float32), lab[..., 2].astype(np.float32)
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    skins = json.loads(r.SKIN_BOUNDING_BOXES)

    def stats(name, boxes):
        ps = []
        for (x1, y1, x2, y2) in boxes:
            ps.append((L[y1:y2 + 1, x1:x2 + 1].mean(), A[y1:y2 + 1, x1:x2 + 1].mean(), B[y1:y2 + 1, x1:x2 + 1].mean()))
        m = np.mean(ps, axis=0)
        return f"{name} L={m[0]:6.1f} a={m[1]:6.1f} b={m[2]:6.1f}"

    h, w = img.shape[:2]
    print(f"{r.PATIENT_ID} ({h}x{w}) Hb={r.HB_LEVEL_GperL} | {stats('nail', nails)} | {stats('skin', skins)} | "
          f"full L={L.mean():6.1f} a={A.mean():6.1f} b={B.mean():6.1f}")
    # Otsu pada L utk cek separasi tangan vs latar
    thr, _ = cv2.threshold(L.astype(np.uint8), 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    hand_frac = float((L.astype(np.uint8) < thr).mean())
    print(f"    Otsu L thr={thr} | fraksi piksel gelap(<thr)={hand_frac:.2f}")