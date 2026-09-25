"""Bulk validation: apply H6 (mirror-x in portrait) to ALL GT boxes,
check centers-in-skin rate and a simple nail-tip proximity metric."""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")

df = pd.read_csv(META)
print(f"Total rows: {len(df)}")

def h6(u, v):
    return (600 - u, v)

def transform_box(box):
    """Transform a single (x1,y1,x2,y2) GT box via H6."""
    (u1,v1), (u2,v2) = box[:2], box[2:]
    tl = h6(u1, v1)
    br = h6(u2, v2)
    # swap if flipped
    x1, x2 = min(tl[0], br[0]), max(tl[0], br[0])
    y1, y2 = min(tl[1], br[1]), max(tl[1], br[1])
    return (x1, y1, x2, y2)

def skin_mask_from_image(img_rot):
    """Simple HSV skin detection on rotated portrait image."""
    hsv = cv2.cvtColor(img_rot, cv2.COLOR_BGR2HSV)
    # skin range: H 0-50, S 40-200, V 80-255
    mask = cv2.inRange(hsv, (0, 40, 80), (50, 200, 255))
    # morphological close + open
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return mask

results = []
skip = 0
for i, row in df.iterrows():
    pid = row.PATIENT_ID
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        skip += 1
        continue
    nails_raw = row.NAIL_BOUNDING_BOXES
    skins_raw = row.SKIN_BOUNDING_BOXES
    if pd.isna(nails_raw) or pd.isna(skins_raw):
        skip += 1
        continue
    try:
        nails = json.loads(nails_raw)
        skins = json.loads(skins_raw)
    except:
        skip += 1
        continue
    if not nails:
        skip += 1
        continue

    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    H, W = img_rot.shape[:2]
    skin = skin_mask_from_image(img_rot)

    total_boxes = 0
    centers_in_skin = 0
    center_in_nail_zone = 0  # center in top portion of finger bbox (near nail)

    for box in nails:
        tb = transform_box(box)
        cx = int((tb[0] + tb[2]) / 2)
        cy = int((tb[1] + tb[3]) / 2)
        total_boxes += 1
        if 0 <= cx < W and 0 <= cy < H:
            if skin[cy, cx] > 0:
                centers_in_skin += 1

    # Also check skin bbox coverage
    for box in skins:
        tb = transform_box(box)
        # check if transformed skin box is mostly inside skin mask
        x1, y1, x2, y2 = [int(v) for v in tb]
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(W-1, x2), min(H-1, y2)
        if x2 <= x1 or y2 <= y1:
            continue
        patch = skin[y1:y2, x1:x2]
        if patch.size == 0:
            continue
        coverage = np.mean(patch > 0)

    skin_pct = (centers_in_skin / total_boxes * 100) if total_boxes > 0 else 0
    results.append({
        'pid': pid,
        'n_nails': len(nails),
        'centers_in_skin': centers_in_skin,
        'total_boxes': total_boxes,
        'skin_pct': skin_pct,
        'W': W, 'H': H,
    })

rdf = pd.DataFrame(results)
print(f"\nProcessed: {len(rdf)} images, skipped: {skip}")
print(f"\n=== H6 (x'=600-u, y'=v) BULK VALIDATION ===")
print(f"Centers in skin: mean {rdf.skin_pct.mean():.1f}%, median {rdf.skin_pct.median():.1f}%")
print(f"100% in skin: {(rdf.skin_pct == 100).sum()}/{len(rdf)} images")
print(f">= 80% in skin: {(rdf.skin_pct >= 80).sum()}/{len(rdf)} images")
print(f">= 50% in skin: {(rdf.skin_pct >= 50).sum()}/{len(rdf)} images")
print(f"\nPer-image skin % distribution:")
print(rdf.skin_pct.value_counts().sort_index().to_string())

# Show worst images (lowest centers-in-skin)
print("\nWorst 10 images (lowest skin %):")
print(rdf.nsmallest(10, 'skin_pct')[['pid', 'n_nails', 'centers_in_skin', 'total_boxes', 'skin_pct']].to_string())
