"""Diagnose: is the contiguous body filter broken by nail/polish gaps?
Dump skin mask + occupancy stats for pid 40/27/32 - verify that admitting
gaps (occupancy >= threshold) rescues the real fingers while still killing
noise dots.
"""
import json
from pathlib import Path
import cv2
import numpy as np
from scipy.ndimage import median_filter
from scipy.signal import find_peaks as fp

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\pcd_eval")
import pandas as pd
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

for pid in [40, 27, 32, 46]:
    row = df[df.PATIENT_ID == pid].iloc[0]
    nails = json.loads(row.NAIL_BOUNDING_BOXES)
    gt_boxes = [h6_transform_box(b) for b in nails]
    img = cv2.imread(str(PHOTO / f"{pid}.jpg"))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    skin = segment_skin(img_rot) > 0
    H, W = skin.shape
    edge = top_edge(skin)
    edge_f = median_filter(edge.astype(float), size=9)

    print(f"\n=== PID {pid} ===")
    peaks, _ = fp(-edge_f, distance=45, prominence=4)
    print(f"  prom=4 peaks: {list(peaks)}")
    for px in peaks:
        px = int(px)
        lo, hi = max(0, px - 14), min(W, px + 15)
        j = int(np.argmin(edge[lo:hi])) + lo
        py = int(edge[j])
        if py >= H - 90:
            print(f"    peak@{px} -> j={j} py={py}: REJECT edge (too low)")
            continue
        col = skin[py:min(H, py + 150), j]
        occ = col.mean() if len(col) else 0.0
        # contiguous run breakdown
        runs = []
        cur = 0
        for v in col:
            if v:
                cur += 1
            else:
                if cur:
                    runs.append(cur)
                cur = 0
        if cur:
            runs.append(cur)
        # nearest GT box center distance
        gts = []
        for (x1, y1, x2, y2) in gt_boxes:
            gx, gy = (x1 + x2) // 2, (y1 + y2) // 2
            gts.append((abs(gx - j), abs(gy - py)))
        print(f"    peak@{px} -> j={j} py={py}: occ={occ:.2f} runs={runs[:4]} "
              f"nearest_gt_dxdy={min(gts)}")

    # also: does occupancy filter pass the REAL finger columns? sample GT cols
    print("  GT columns occupancy:")
    for (x1, y1, x2, y2) in gt_boxes:
        gx = (x1 + x2) // 2
        px = int(np.argmin(edge[max(0, gx - 8):min(W, gx + 9)])) + max(0, gx - 8)
        py = int(edge[px])
        col = skin[py:min(H, py + 150), px]
        occ = col.mean() if len(col) else 0.0
        print(f"    gt_x={gx} gt_top={y1}: refined j={px} py={py} occ={occ:.2f}")

    # dump mask overlay for eyeballing
    vis = np.zeros((H, W, 3), dtype=np.uint8)
    vis[skin] = (230, 230, 230)
    for (x1, y1, x2, y2) in gt_boxes:
        cv2.rectangle(vis, (x1, y1), (x2, y2), (0, 220, 255), 2)
    out_p = OUT / f"diag_mask_{pid}.png"
    cv2.imwrite(str(out_p), vis)
    print(f"  wrote {out_p}")