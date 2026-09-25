"""Measure actual vertical offset from fingertip peak to GT nail top.

For each GT box:
  1. Find the fingertip peak column nearest to GT center x (within ±40px)
  2. Measure d = edge_at_peak - gt_top_y  (negative = peak above nail)
  3. Also measure d_multi for offsets 0..80 step 5: IoU if box placed there
  4. Report which offset gives best recall@0.5
"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd
from scipy.ndimage import median_filter
from scipy.signal import find_peaks as fp

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
df = pd.read_csv(META)

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

def top_edge(skin):
    H, W = skin.shape
    edge = np.full(W, H, dtype=int)
    for x in range(W):
        rows = np.where(skin[:, x] > 0)[0]
        if len(rows) > 0:
            edge[x] = rows[0]
    return edge

def iou(a, b):
    xa, ya = max(a[0], b[0]), max(a[1], b[1])
    xb, yb = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, xb - xa) * max(0, yb - ya)
    aa = (a[2]-a[0])*(a[3]-a[1])
    ab = (b[2]-b[0])*(b[3]-b[1])
    u = aa + ab - inter
    return inter / u if u > 0 else 0

# Collect data
offsets_actual = []   # edge[px] - gt_top for nearest peak
best_offsets = []     # per GT, which offset (0-80 step 5) gives max IoU

# Multi-offset sweep: for each GT, try placing box at offset 0..80 step 5
# from the peak edge value, measure IoU with GT
offset_recalls = {o: 0 for o in range(0, 85, 5)}  # offset -> count matched (IoU >= 0.3)
offset_recalls_strict = {o: 0 for o in range(0, 85, 5)}
total_gt = 0

for _, row in df.iterrows():
    pid = row.PATIENT_ID
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        continue
    try:
        nails = json.loads(row.NAIL_BOUNDING_BOXES)
    except:
        continue
    if not nails:
        continue
    gt_boxes = [h6_transform_box(b) for b in nails]
    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    skin = segment_skin(img_rot)
    edge = top_edge(skin)
    edge_f = median_filter(edge.astype(float), size=9)
    peaks, _ = fp(-edge_f, distance=45, prominence=10)
    if len(peaks) == 0:
        continue
    H, W = skin.shape
    for (x1, y1, x2, y2) in gt_boxes:
        xc = (x1 + x2) // 2
        total_gt += 1
        # find nearest peak within ±40px in x
        dists = np.abs(peaks.astype(int) - xc)
        nearest_idx = np.argmin(dists)
        if dists[nearest_idx] > 40:
            offsets_actual.append(np.nan)
            continue
        px = int(peaks[nearest_idx])
        py = int(edge[px])   # smoothed fingertip height at peak
        d = py - y1          # negative = fingertip above nail
        offsets_actual.append(d)
        # try each offset
        for off in range(0, 85, 5):
            top = py + off
            bx1, by1 = max(0, px - 25), top
            bx2, by2 = min(W, px + 25), top + 55
            box = (bx1, by1, bx2, by2)
            v = iou(box, (x1, y1, x2, y2))
            if v >= 0.3:
                offset_recalls[off] += 1
            if v >= 0.5:
                offset_recalls_strict[off] += 1

arr = np.array([v for v in offsets_actual if not np.isnan(v)])
print(f"GT with nearby peak: {len(arr)}/{total_gt} ({len(arr)/total_gt*100:.1f}%)")
print(f"\nActual offset d = edge[peak_x] - gt_top (negative = peak above nail):")
print(f"  mean {arr.mean():.1f}  median {np.median(arr):.0f}  "
      f"p10 {np.percentile(arr,10):.0f}  p25 {np.percentile(arr,25):.0f}  "
      f"p75 {np.percentile(arr,75):.0f}  p90 {np.percentile(arr,90):.0f}")
print(f"\nBest offset for recall@0.3:")
best30 = max(offset_recalls, key=offset_recalls.get)
print(f"  offset={best30}  recall={offset_recalls[best30]}/{len(arr)} ({offset_recalls[best30]/len(arr)*100:.1f}%)")
print(f"\nBest offset for recall@0.5:")
best50 = max(offset_recalls_strict, key=offset_recalls_strict.get)
print(f"  offset={best50}  recall={offset_recalls_strict[best50]}/{len(arr)} ({offset_recalls_strict[best50]/len(arr)*100:.1f}%)")
print(f"\nOffset sweep (recall@0.3 / recall@0.5):")
for off in range(0, 85, 5):
    r30 = offset_recalls[off] / len(arr) * 100 if len(arr) else 0
    r50 = offset_recalls_strict[off] / len(arr) * 100 if len(arr) else 0
    print(f"  off={off:2d}:  {r30:5.1f}% / {r50:5.1f}%")
