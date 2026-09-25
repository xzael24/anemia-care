"""Probe: is low IoU caused by candidate SIZE or POSITION?

For each image:
  1. Candidate centroids from current find_nails (position only)
  2. "Grown" candidate = GT-median box (50x55) centered at candidate centroid
  3. Ceiling recall@0.5 if we only fixed the size (using candidates' positions)
  4. Also: distance from GT box top edge to topmost skin pixel in that column span
     -> tells us whether nails sit at the TOP tips of fingers (fingers pointing up)
"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
df = pd.read_csv(META)

TARGET_W, TARGET_H = 50, 55  # GT median


def h6_transform_box(box):
    (u1, v1), (u2, v2) = box[:2], box[2:]
    x1, x2 = sorted([600 - u1, 600 - u2])
    y1, y2 = sorted([v1, v2])
    return (x1, y1, x2, y2)


def segment_skin(img_rot):
    hsv = cv2.cvtColor(img_rot, cv2.COLOR_BGR2HSV)
    m1 = cv2.inRange(hsv, np.array([0, 25, 30]), np.array([50, 255, 255]))
    m2 = cv2.inRange(hsv, np.array([160, 25, 30]), np.array([180, 255, 255]))
    mask = cv2.bitwise_or(m1, m2)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return mask


def find_candidate_centroids(skin, img_rot):
    """Same heuristic as current find_nails but returns centroids+size only."""
    H, W = skin.shape
    ys, xs = np.where(skin > 0)
    if len(ys) == 0:
        return []
    skin_top, skin_bot = ys.min(), ys.max()
    band_bot = min(H, int(skin_top + (skin_bot - skin_top) * 0.55))
    band = skin.copy()
    band[band_bot:, :] = 0

    dist = cv2.distanceTransform(band, cv2.DIST_L2, 5)
    maxd = dist.max()
    if maxd < 2:
        return []
    _, thresh = cv2.threshold(dist.astype(np.uint8), maxd * 0.5, 255, cv2.THRESH_BINARY)
    thresh = thresh.astype(np.uint8)
    n_labels, _, stats, centroids = cv2.connectedComponentsWithStats(thresh)
    cands = []
    for i in range(1, n_labels):
        x, y, w, h, area = stats[i]
        if area < 150 or area > 20000:
            continue
        aspect = w / max(h, 1)
        if aspect < 0.25 or aspect > 4.0:
            continue
        if w > W * 0.45 or h > H * 0.30:
            continue
        cands.append((centroids[i][0], centroids[i][1], w, h))
    return cands


def iou(a, b):
    xa, ya = max(a[0], b[0]), max(a[1], b[1])
    xb, yb = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, xb - xa) * max(0, yb - ya)
    aa = (a[2] - a[0]) * (a[3] - a[1])
    ab = (b[2] - b[0]) * (b[3] - b[1])
    u = aa + ab - inter
    return inter / u if u > 0 else 0


sizes = []
pos_matches_05 = []      # per-image ceiling recall@0.5 with size fixed
pos_matches_03 = []
dist_top_edge = []       # distance GT-top -> skin topmost in GT column span
n_within_30 = 0
n_total_gt = 0

for _, row in df.iterrows():
    pid = row.PATIENT_ID
    img_path = PHOTO / f"{pid}.jpg"
    try:
        nails = json.loads(row.NAIL_BOUNDING_BOXES)
    except Exception:
        continue
    if not nails or not img_path.exists():
        continue
    gt_boxes = [h6_transform_box(b) for b in nails]
    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    H, W = img_rot.shape[:2]
    skin = segment_skin(img_rot)

    cands = find_candidate_centroids(skin, img_rot)
    top_rows = np.where(skin.any(axis=1))[0]

    # ceiling recall: greedy match GT with grown candidate boxes
    grown = []
    for cx, cy, w, h in cands:
        x1 = int(cx - TARGET_W / 2); y1 = int(cy - TARGET_H / 2)
        grown.append((x1, y1, x1 + TARGET_W, y1 + TARGET_H))
    pairs = []
    for ci, gbox in enumerate(grown):
        for gi, g in enumerate(gt_boxes):
            v = iou(gbox, g)
            if v > 0:
                pairs.append((v, ci, gi))
    pairs.sort(reverse=True)
    used_gt, matched_c = set(), set()
    hits05 = hits03 = 0
    for v, ci, gi in pairs:
        if ci in matched_c or gi in used_gt:
            continue
        matched_c.add(ci); used_gt.add(gi)
        if v >= 0.5: hits05 += 1
        if v >= 0.3: hits03 += 1
    pos_matches_05.append(hits05 / len(gt_boxes))
    pos_matches_03.append(hits03 / len(gt_boxes))

    for g in gt_boxes:
        x1, y1, x2, y2 = g
        col_span = skin[y1:y2 + 1, max(0, x1):min(W, x2)]
        if col_span.size == 0:
            continue
        rows_skin = np.where(col_span.any(axis=1))[0]
        if len(rows_skin) == 0:
            continue
        top_in_box = y1 + rows_skin[0]
        dist_top_edge.append(top_in_box - (top_rows.min() if len(top_rows) else y1))
        if (top_in_box - top_rows.min()) <= 30:
            n_within_30 += 1
        n_total_gt += 1

print(f"Images: {len(pos_matches_05)}, GT boxes: {n_total_gt}")
p05 = np.array(pos_matches_05)
p03 = np.array(pos_matches_03)
print(f"\nCeiling if SIZE fixed to 50x55 (positions from current heuristic):")
print(f"  recall@0.5: mean {p05.mean():.3f}, median {np.median(p05):.3f}, =1.0: {(p05 == 1).sum()}/{len(p05)}, =0: {(p05 == 0).sum()}/{len(p05)}")
print(f"  recall@0.3: mean {p03.mean():.3f}, median {np.median(p03):.3f}")
print(f"\nGT top edge vs global skin top (orientasi jari):")
d = np.array(dist_top_edge)
print(f"  median gap {np.median(d):.0f}px, mean {d.mean():.0f}px, p25 {np.percentile(d,25):.0f}, p75 {np.percentile(d,75):.0f}")
print(f"  GT boxes whose top is within 30px of global skin top: {n_within_30}/{n_total_gt} ({n_within_30/n_total_gt*100:.0f}%)")