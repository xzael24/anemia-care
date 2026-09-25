"""Overlay di rotated image dengan beberapa scale factor — cari yang pas."""
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
scales = [0.8, 1.0, 1.2, 1.4, 1.6, 1.8]
colors_s = {
    0.8: (255,0,0), 1.0: (0,255,0), 1.2: (0,0,255),
    1.4: (255,255,0), 1.6: (0,255,255), 1.8: (255,0,255),
}

for pid in [288, 54]:
    r = df[df.PATIENT_ID == pid].iloc[0]
    img = cv2.imread(str(PHOTO / f"{pid}.jpg"))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)  # 800H x 600W
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    skins = json.loads(r.SKIN_BOUNDING_BOXES)
    for s in scales:
        overlay = img_rot.copy()
        for (x1, y1, x2, y2) in nails:
            a, b, c, d = int(x1*s), int(y1*s), int(x2*s), int(y2*s)
            cv2.rectangle(overlay, (a, b), (c, d), colors_s[s], 2)
        for (x1, y1, x2, y2) in skins:
            a, b, c, d = int(x1*s), int(y1*s), int(x2*s), int(y2*s)
            cv2.rectangle(overlay, (a, b), (c, d), colors_s[s], 1)
        label = f"nail={colors_s[s]} s={s}"
        cv2.putText(overlay, label, (10, 25 + 20 * scales.index(s)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, colors_s[s], 1, cv2.LINE_AA)
    cv2.imwrite(str(OUT / f"{pid}_rot_scalegrid.png"), overlay)
    print(f"saved {pid}")
