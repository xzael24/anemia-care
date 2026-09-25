"""Probe: measure fingertip-to-nail offset using top-edge profile.

For each image (rotated portrait):
  1. Skin mask → per-column topmost skin pixel → top_edge[x] = min_y
  2. Smooth + find local MINIMA (fingertips = fingers reach upward = low y)
  3. For each peak, find nearest GT box center below it (within 100px x, within 80px y)
  4. Report offset distribution (x-distance, y-distance from fingertip to GT center)
  5. Report: how many GT boxes have a fingertip "nearby"?

This tells us:
  - What is the pad offset (fingertip above nail)?
  - Do ALL GT boxes have a clear fingertip peak above them?
  - What is the correct x-distance tolerance?
"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd
from scipy.signal import find_peaks

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
    """Per-column topmost skin pixel row (H if no skin)."""
    H, W = skin.shape
    edge = np.full(W, H, dtype=int)
    for x in range(W):
        rows = np.where(skin[:, x] > 0)[0]
        if len(rows) > 0:
            edge[x] = rows[0]
    return edge


def find_fingertip_peaks(edge, min_dist=40, prominence=8):
    """Find local minima (fingertips) in the top-edge curve."""
    # Negate so peaks become maxima for find_peaks
    neg = -edge.astype(float)
    # Smooth slightly
    from scipy.ndimage import uniform_filter1d
    neg_smooth = uniform_filter1d(neg, size=5)
    peaks, props = find_peaks(neg_smooth, distance=min_dist, prominence=prominence)
    return peaks, neg_smooth


# ---------- collect stats ----------
all_pad_offsets = []
all_x_offsets = []
matched_count = 0
total_gt = 0
n_fingerpeaks = []
n_gts_per_image = []

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
    gt_centers = [((b[0]+b[2])//2, (b[1]+b[3])//2) for b in gt_boxes]

    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    skin = segment_skin(img_rot)
    edge = top_edge(skin)
    peaks, _ = find_fingertip_peaks(edge, min_dist=35, prominence=5)

    n_fingerpeaks.append(len(peaks))
    n_gts_per_image.append(len(gt_boxes))

    # For each GT box, find nearest fingertip peak (in x) that is ABOVE the GT center (lower y)
    for gx, gy in gt_centers:
        total_gt += 1
        best_peak_y = None
        best_dx = None
        for px in peaks:
            dx = abs(px - gx)
            if dx > 80:
                continue
            # fingertip must be above GT center (lower y = higher in image)
            if edge[px] >= gy:
                continue
            if best_peak_y is None or edge[px] < best_peak_y:
                best_peak_y = edge[px]
                best_dx = dx
        if best_peak_y is not None:
            matched_count += 1
            all_pad_offsets.append(gy - best_peak_y)  # positive = fingertip above nail
            all_x_offsets.append(best_dx)

print(f"Images analyzed: {df.shape[0]}")
print(f"Total GT boxes: {total_gt}, GT with nearby fingertip: {matched_count} ({matched_count/total_gt*100:.1f}%)")
print(f"\nFingertip peaks per image: mean {np.mean(n_fingerpeaks):.1f}, median {np.median(n_fingerpeaks):.0f}, "
      f"GT per image: mean {np.mean(n_gts_per_image):.1f}, median {np.median(n_gts_per_image):.0f}")

if all_pad_offsets:
    po = np.array(all_pad_offsets)
    xo = np.array(all_x_offsets)
    print(f"\nPad offset (fingertip_y to GT_center_y, px):")
    print(f"  mean {po.mean():.1f}, median {np.median(po):.1f}, p10 {np.percentile(po,10):.1f}, "
          f"p25 {np.percentile(po,25):.1f}, p75 {np.percentile(po,75):.1f}, p90 {np.percentile(po,90):.1f}")
    print(f"  min {po.min():.1f}, max {po.max():.1f}")
    print(f"\nX offset (fingertip vs GT center, px):")
    print(f"  mean {xo.mean():.1f}, median {np.median(xo):.1f}, p90 {np.percentile(xo,90):.1f}")
    print(f"  ≤20px: {(xo<=20).sum()}/{len(xo)} ({(xo<=20).mean()*100:.0f}%)")
    print(f"  ≤40px: {(xo<=40).sum()}/{len(xo)} ({(xo<=40).mean()*100:.0f}%)")
else:
    print("\nNo fingertip-GT matches found!")
