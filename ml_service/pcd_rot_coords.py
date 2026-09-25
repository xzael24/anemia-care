"""Overlay with rotated coords + scale: GT portrait → rotate 90 CW → scale."""
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

def rotate_90cw(x1, y1, x2, y2, W_src=600, H_src=800):
    """Rotate bbox 90° CW: portrait coords (up to 336x768) → landscape display.
    In the rotated image: x_new = y_old, y_new = W_src - x_old.
    We return (x1_new, y1_new, x2_new, y2_new) ordered correctly."""
    # Transform all 4 corners
    corners = [(x1,y1),(x2,y1),(x1,y2),(x2,y2)]
    new_corners = [(y, W_src - x) for (x, y) in corners]
    xs = [c[0] for c in new_corners]
    ys = [c[1] for c in new_corners]
    return (min(xs), min(ys), max(xs), max(ys))

scales = [0.8, 1.0, 1.14, 1.25, 1.5, 1.8, 2.0]
colors_s = {
    0.8: (255,0,0), 1.0: (0,255,0), 1.14: (0,0,255),
    1.25: (255,255,0), 1.5: (0,255,255), 1.8: (255,0,255),
    2.0: (128,0,255),
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
            rx1, ry1, rx2, ry2 = rotate_90cw(x1, y1, x2, y2, W_src=W, H_src=H)
            a, b, c, d = int(rx1*s), int(ry1*s), int(rx2*s), int(ry2*s)
            cv2.rectangle(overlay, (a, b), (c, d), col, 2)
        for (x1, y1, x2, y2) in skins:
            rx1, ry1, rx2, ry2 = rotate_90cw(x1, y1, x2, y2, W_src=W, H_src=H)
            a, b, c, d = int(rx1*s), int(ry1*s), int(rx2*s), int(ry2*s)
            cv2.rectangle(overlay, (a, b), (c, d), col, 1)
        lx, ly = 10, 20 + i*20
        cv2.rectangle(overlay, (lx, ly-14), (lx+14, ly+2), col, -1)
        cv2.putText(overlay, f"s={s}", (lx+18, ly), cv2.FONT_HERSHEY_SIMPLEX, 0.45, col, 1, cv2.LINE_AA)

    cv2.imwrite(str(OUT / f"{pid}_rot90cw_coords.png"), overlay)
    print(f"\n{pid}: rotated image {W}x{H}")
    for (x1, y1, x2, y2) in nails:
        rx1, ry1, rx2, ry2 = rotate_90cw(x1, y1, x2, y2, W_src=W, H_src=H)
        print(f"  GT nail ({x1},{y1})-({x2},{y2}) → rot ({rx1},{ry1})-({rx2},{ry2})")
