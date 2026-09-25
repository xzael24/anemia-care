"""Quick diagnostic: why pid 40, 27, 32 get 0 candidates."""
import json
from pathlib import Path
import cv2
import numpy as np
from scipy.ndimage import median_filter
from scipy.signal import find_peaks as fp

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
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
    skin = segment_skin(img_rot)
    H, W = skin.shape
    edge = top_edge(skin)
    edge_f = median_filter(edge.astype(float), size=9)

    print(f"\n=== PID {pid} ===")
    print(f"  Image: {img_rot.shape}, skin px: {np.sum(skin>0)}")
    print(f"  GT boxes: {gt_boxes}")
    gt_centers = [( (x1+x2)//2, (y1+y2)//2 ) for x1,y1,x2,y2 in gt_boxes]
    print(f"  GT centers: {gt_centers}")
    print(f"  edge values at GT centers x: {[edge[cx] for cx,_ in gt_centers]}")
    print(f"  edge_f range: [{edge_f.min():.0f}, {edge_f.max():.0f}]")
    print(f"  edge == H (no skin): {np.sum(edge==H)}/{W}")

    for prom in [3, 4, 5, 6, 8, 10]:
        peaks, props = fp(-edge_f, distance=45, prominence=prom)
        print(f"  prominence={prom}: {len(peaks)} peaks at x={list(peaks)}")
        for px in peaks:
            px = int(px)
            lo, hi = max(0, px-14), min(W, px+15)
            j = int(np.argmin(edge[lo:hi])) + lo
            py = int(edge[j])
            # body height
            body = 0
            for yr in range(py, min(H, py+150)):
                if skin[yr, j] > 0:
                    body += 1
                else:
                    break
            print(f"    peak@{px} -> refined j={j}, py={py}, body={body}, "
                  f"py>=H-90={py >= H - 90}, body<70={body<70}")

    # Also check: what if we use prominence=6 and NO body filter?
    peaks6, _ = fp(-edge_f, distance=45, prominence=6)
    rejected_body = 0
    rejected_edge = 0
    accepted = 0
    for px in peaks6:
        px = int(px)
        lo, hi = max(0, px-14), min(W, px+15)
        j = int(np.argmin(edge[lo:hi])) + lo
        py = int(edge[j])
        if py >= H - 90:
            rejected_edge += 1
            continue
        body = 0
        for yr in range(py, min(H, py+150)):
            if skin[yr, j] > 0:
                body += 1
            else:
                break
        if body < 70:
            rejected_body += 1
        else:
            accepted += 1
    print(f"  Summary: peaks={len(peaks6)}, accepted={accepted}, "
          f"rejected_edge={rejected_edge}, rejected_body={rejected_body}")
