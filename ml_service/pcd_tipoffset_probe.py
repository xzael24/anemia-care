"""Probe 2: direct top-edge measurement at GT nail columns.

For each GT box (rotated portrait):
  1. top_edge[x] = topmost skin row per column
  2. At xc = GT center column:
       d_top  = gt_top_y - top_edge[xc]   -> pad of fingertip above nail at nail column
       ed_pt1 = gt_top_y - median(top_edge[xc-8..xc+8])  (robust)
  3. Nail row strip y_n = gt_top_y + 10:
       measure finger span (left/right skin bounds around xc) -> finger width at nail
  4. Also detect: is the fingertip (low point of edge near xc) ABOVE the nail?
       min(edge[xc-15..xc+15]) vs gt_top

Answers:
  - At the nail column, how far is the fingertip top above the nail top? (per-finger pad)
  - Is the nail column inside the fingertip plateau (edge low) or on the slope?
  - Finger width at nail row -> nail box width scale.
"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd

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


d_tops = []
d_tops_robust = []
tip_minus_gt_top = []
finger_widths = []
nail_on_plateau = []      # top edge near xc is within +25 of min in window
gt_heights = []
gt_widths = []

for _, row in df.iterrows():
    pid = row.PATIENT_ID
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        continue
    try:
        nails = json.loads(row.NAIL_BOUNDING_BOXES)
    except Exception:
        continue
    if not nails:
        continue
    gt_boxes = [h6_transform_box(b) for b in nails]

    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    skin = segment_skin(img_rot)
    edge = top_edge(skin)
    H, W = skin.shape

    for (x1, y1, x2, y2) in gt_boxes:
        xc = (x1 + x2) // 2
        gt_h = y2 - y1
        gt_w = x2 - x1
        gt_heights.append(gt_h)
        gt_widths.append(gt_w)
        if xc - 8 < 0 or xc + 8 >= W:
            continue

        ed = edge[xc]
        d_tops.append(y1 - ed)

        lo = max(0, xc - 8)
        hi = min(W, xc + 8)
        med_edge = np.median(edge[lo:hi])
        d_tops_robust.append(y1 - med_edge)

        # min of edge in window around nail column
        wlo = max(0, xc - 15)
        whi = min(W, xc + 15)
        win = edge[wlo:whi]
        min_in_win = win.min()
        tip_minus_gt_top.append(min_in_win - y1)
        # plateau if edge at xc is not much below the window min
        nail_on_plateau.append((ed - min_in_win) <= 25)

        # finger width at nail row: left/right skin bounds at row y1+10
        yr = min(H - 1, y1 + 10)
        rowskin = np.where(skin[yr, :] > 0)[0]
        if len(rowskin) > 0:
            # the bounded component containing xc
            comp = rowskin[(rowskin >= xc - 120) & (rowskin <= xc + 120)]
            left = comp[comp <= xc]
            right = comp[comp >= xc]
            if len(left) > 0 and len(right) > 0:
                finger_widths.append(right[0] - left[-1])

arr = {k: np.array(v) for k, v in dict(
    d_tops=d_tops, d_tops_robust=d_tops_robust, tip_minus_gt_top=tip_minus_gt_top,
    finger_widths=finger_widths, gt_heights=gt_heights, gt_widths=gt_widths).items()}

print(f"GT boxes: {len(d_tops)}")
for name, a in arr.items():
    if len(a) == 0:
        continue
    print(f"\n{name} (n={len(a)}):")
    print(f"  mean {a.mean():.1f}  median {np.median(a):.0f}  "
          f"p10 {np.percentile(a,10):.0f}  p25 {np.percentile(a,25):.0f}  "
          f"p75 {np.percentile(a,75):.0f}  p90 {np.percentile(a,90):.0f}")

print(f"\nNail column on fingertip plateau (edge[xc] - winmin <= 25): "
      f"{np.sum(nail_on_plateau)}/{len(nail_on_plateau)} ({np.mean(nail_on_plateau)*100:.1f}%)")