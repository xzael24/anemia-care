"""Check the worst 0%-in-skin images: widen skin mask AND save overlays
to see whether the transform is wrong or just the mask is too narrow."""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\scale_probe")

df = pd.read_csv(META)

def transform_box(box):
    """H6: (x',y') = (600-u, v)"""
    (u1, v1), (u2, v2) = box[:2], box[2:]
    x1, x2 = 600 - u2, 600 - u1
    y1, y2 = min(v1, v2), max(v1, v2)
    return (min(x1, x2), y1, max(x1, x2), y2)

def skin_mask(img, wide=False):
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    if wide:
        # very wide: H 0-180 wrap, S 20-255, V 30-255
        low = np.array([0, 20, 30])
        high = np.array([180, 255, 255])
        m1 = cv2.inRange(hsv, low, high)
        # second mask for pure red-skinned (H near 0 AND near 180)
        m2 = cv2.inRange(hsv, (160, 30, 30), (180, 255, 255))
        m3 = cv2.inRange(hsv, (0, 30, 30), (10, 255, 255))
        mask = cv2.bitwise_or(cv2.bitwise_or(m1, m2), m3)
    else:
        mask = cv2.inRange(hsv, (0, 40, 80), (50, 200, 255))
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return mask

worst = [1, 5, 6, 7, 14]  # a sample of 0% pids

for pid in worst:
    row = df[df.PATIENT_ID == pid].iloc[0]
    nails = json.loads(row.NAIL_BOUNDING_BOXES)
    img = cv2.imread(str(PHOTO / f"{pid}.jpg"))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    H, W = img_rot.shape[:2]
    skin = skin_mask(img_rot, wide=False)
    skin_wide = skin_mask(img_rot, wide=True)

    def stats(mask, label):
        hits = 0
        for b in nails:
            tb = transform_box(b)
            cx, cy = int((tb[0] + tb[2]) / 2), int((tb[1] + tb[3]) / 2)
            if 0 <= cx < W and 0 <= cy < H and mask[cy, cx] > 0:
                hits += 1
        pct = hits / len(nails) * 100
        print(f"  pid {pid}: {label}: {pct:.0f}% ({hits}/{len(nails)})")
        return pct

    stats(skin, "narrow mask")
    stats(skin_wide, "wide mask  ")

    # overlay: draw transformed GT boxes on rotated image
    ov = img_rot.copy()
    for b in nails:
        tb = transform_box(b)
        x1, y1, x2, y2 = [int(v) for v in tb]
        cv2.rectangle(ov, (x1, y1), (x2, y2), (0, 0, 255), 3)
        cx, cy = int((x1 + x2) / 2), int((y1 + y2) / 2)
        cv2.circle(ov, (cx, cy), 6, (255, 0, 255), -1)
    out = OUT / f"{pid}_worst_check.png"
    cv2.imwrite(str(out), ov)
    print(f"  -> saved {out}")

print("\ndone")