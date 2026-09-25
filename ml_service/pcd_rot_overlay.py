"""Cek: rotasi EXIF (90 CW) → overlay GT langsung tanpa scale — bbox nempel?"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\scale_probe")

df = pd.read_csv(META)
for pid in [288, 54, 47]:
    r = df[df.PATIENT_ID == pid].iloc[0]
    img = cv2.imread(str(PHOTO / f"{pid}.jpg"))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)  # portrait: 800x600
    nails = json.loads(r.NAIL_BOUNDING_BOXES)
    skins = json.loads(r.SKIN_BOUNDING_BOXES)
    for (x1, y1, x2, y2) in nails:
        cv2.rectangle(img_rot, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
    for (x1, y1, x2, y2) in skins:
        cv2.rectangle(img_rot, (int(x1), int(y1)), (int(x2), int(y2)), (255, 0, 0), 2)
    cv2.imwrite(str(OUT / f"{pid}_rot_overlay.png"), img_rot)
    print(pid, img_rot.shape)
