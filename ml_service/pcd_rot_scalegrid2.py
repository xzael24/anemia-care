"""Overlay di rotated image — scale grid lebar + single scale detail."""
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

# --- Grid 1: many scales on rotated image ---
scales = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
colors_s = {
    0.5: (255,0,0), 0.75: (0,255,0), 1.0: (0,0,255),
    1.25: (255,255,0), 1.5: (0,255,255), 2.0: (255,0,255),
    2.5: (0,128,255), 3.0: (128,0,255),
}

for pid in [288, 54]:
    r = df[df.PATIENT_ID == pid].iloc[0]
    img = cv2.imread(str(PHOTO / f"{pid}.jpg"))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)  # 800H x 600W
    H, W = img_rot.shape[:2]
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    skins = json.loads(r.SKIN_BOUNDING_BOXES)
    
    overlay = img_rot.copy()
    for i, s in enumerate(scales):
        col = colors_s[s]
        for (x1, y1, x2, y2) in nails:
            a, b, c, d = int(x1*s), int(y1*s), int(x2*s), int(y2*s)
            cv2.rectangle(overlay, (a, b), (c, d), col, 1)
        for (x1, y1, x2, y2) in skins:
            a, b, c, d = int(x1*s), int(y1*s), int(x2*s), int(y2*s)
            cv2.rectangle(overlay, (a, b), (c, d), col, 1)
        # legend
        lx, ly = 10, 20 + i*18
        cv2.rectangle(overlay, (lx, ly-12), (lx+12, ly+2), col, -1)
        cv2.putText(overlay, f"s={s}", (lx+16, ly), cv2.FONT_HERSHEY_SIMPLEX, 0.4, col, 1, cv2.LINE_AA)
    cv2.imwrite(str(OUT / f"{pid}_rot_scalegrid_wide.png"), overlay)
    print(f"saved {pid} — img {W}x{H}")
    # Also print where nails appear in the image
    for (x1, y1, x2, y2) in nails:
        cx, cy = (x1+x2)//2, (y1+y2)//2
        print(f"  GT nail: ({x1},{y1})-({x2},{y2}) center=({cx},{cy})")
