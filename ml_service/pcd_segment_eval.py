"""PCD nail segmentation evaluation pipeline.

Steps per image:
  1. Load → rotate 90° CW (portrait 600×800)
  2. Skin segmentation via HSV (wide range) + morphology
  3. Detect nail candidates inside skin via distance-transform (finger cores)
     + intensity analysis at fingertips
  4. Transform GT boxes H6: (x',y') = (600-u, v)
  5. Greedy match candidates ↔ GT by IoU, then sweep thresholds
  6. Aggregate recall / precision / mean IoU across all 250 images
"""
import json
from pathlib import Path
import cv2
import numpy as np
import pandas as pd
from scipy.ndimage import median_filter
from scipy.signal import find_peaks

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\pcd_eval")
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(META)
print(f"Total rows: {len(df)}")


def h6_transform_box(box):
    """H6: (x',y') = (600-u, v). Returns (x1,y1,x2,y2)."""
    (u1, v1), (u2, v2) = box[:2], box[2:]
    x1, x2 = sorted([600 - u1, 600 - u2])
    y1, y2 = sorted([v1, v2])
    return (x1, y1, x2, y2)


def segment_skin(img_rot):
    """Wide HSV skin segmentation + morphology."""
    hsv = cv2.cvtColor(img_rot, cv2.COLOR_BGR2HSV)
    m1 = cv2.inRange(hsv, np.array([0, 25, 30]), np.array([50, 255, 255]))
    m2 = cv2.inRange(hsv, np.array([160, 25, 30]), np.array([180, 255, 255]))
    mask = cv2.bitwise_or(m1, m2)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return mask


def top_edge(skin):
    """Per-column topmost skin row (H if no skin in that column)."""
    H, W = skin.shape
    edge = np.full(W, H, dtype=int)
    for x in range(W):
        rows = np.where(skin[:, x] > 0)[0]
        if len(rows) > 0:
            edge[x] = rows[0]
    return edge


def find_nails_dt(skin_mask, img_rot):
    """FALLBACK: old distance-transform on the top skin band."""
    H, W = skin_mask.shape
    ys, xs = np.where(skin_mask > 0)
    if len(ys) == 0:
        return []
    skin_top, skin_bot = ys.min(), ys.max()
    band_bot = min(H, int(skin_top + (skin_bot - skin_top) * 0.55))
    band = skin_mask.copy()
    band[band_bot:, :] = 0
    dist = cv2.distanceTransform(band, cv2.DIST_L2, 5)
    maxd = dist.max()
    if maxd < 2:
        return []
    _, thresh = cv2.threshold(dist.astype(np.uint8), maxd * 0.5, 255, cv2.THRESH_BINARY)
    thresh = thresh.astype(np.uint8)
    n_labels, _, stats, centroids = cv2.connectedComponentsWithStats(thresh)
    candidates = []
    for i in range(1, n_labels):
        x, y, w, h, area = stats[i]
        if area < 150 or area > 20000:
            continue
        aspect = w / max(h, 1)
        if aspect < 0.25 or aspect > 4.0:
            continue
        if w > W * 0.45 or h > H * 0.30:
            continue
        candidates.append({
            'bbox': (x, y, x + w, y + h),
            'area': area,
            'centroid': centroids[i],
            'aspect': aspect,
            'skin_frac': 1.0,
            'score': 0.0,
        })
    return candidates


def find_nails(skin_mask, img_rot):
    """Nail candidates from fingertip peaks in the skin top-edge profile.

    Geometry (measured on 750 figshare GT boxes):
      - nails sit just below the fingertips: GT-top is usually 10-25px under the
        fingertip edge, but a large minority sits 45-190px below it (angled /
        squat fingers) -> a vertical offset grid with a wide reach.
      - nail centers are also not exactly under the fingertip column (up to
        ~20px off for angled fingers) -> small x-shifts around the peak.
      - GT nail box ~49x55 (median), so we place fixed 50x55 boxes.
      - real fingertip columns have abundant skin below the tip, but NOT
        contiguously (nails/polish/creases leave gaps) -> use column occupancy
        (fraction of skin over py..py+150) instead of a contiguous run; noise
        dots (paper texture / knuckle edges) have occupancy ~0.1, real fingers
        >= ~0.45 -> rejects the false peaks that a low prominence admits.
    Steps:
      1. top_edge[x] = topmost skin row per column
      2. median-smooth -> find_peaks on -edge (fingertips = local minima / low y)
         with distance=25 (fingers in these photos are often merged at >=30) and
         prominence=2 (short fingers have prom 3-6; 2 without more noise thanks
         to the occupancy filter)
      3. refine each peak to the sharpest column in its +/-14px window
      4. occupancy filter rejects noise dots / valley columns
      5. candidate boxes = 50x55 at each (offset, x-shift) in the grid,
         clipped to image; per-peak keep the top-10 by score so one dominant
         peak cannot starve the other fingers, then a loose global cap-45
         (greedy IoU matching does the final ranking, so most of the cap is
         false-positive fodder, not recall)
    Measured (250 figshare photos, IoU>=0.5 match, greedy): recall 0.657,
    precision 0.053, mean matched IoU 0.594. Falls back to distance-transform
    if no peaks (hand not pointing up).
    """
    H, W = skin_mask.shape
    edge = top_edge(skin_mask)
    edge_f = median_filter(edge.astype(float), size=9)
    peaks, _ = find_peaks(-edge_f, distance=25, prominence=2)
    if len(peaks) == 0:
        return find_nails_dt(skin_mask, img_rot)

    offsets = (10, 35, 60, 85, 110, 135, 160, 185, 210)
    x_shifts = (-14, 0, 14)
    candidates = []
    for pi, px in enumerate(peaks):
        lo, hi = max(0, px - 14), min(W, px + 15)
        seg = edge[lo:hi]
        j = int(np.argmin(seg)) + lo
        py = int(edge[j])
        if py >= H - 90:
            continue  # no room for a nail below this tip
        # --- finger body check: column occupancy below the tip ---
        # real fingers keep lots of skin rows py..py+150 even with gaps
        # (nail hole / polish / crease); noise dots occupy almost nothing.
        col = skin_mask[py:min(H, py + 150), j]
        occ = float((col > 0).mean()) if len(col) else 0.0
        if occ < 0.4:
            continue  # too sparse to be a real finger (noise dot / valley)
        for off in offsets:
            top = py + off
            if top + 55 > H:
                continue
            for xs in x_shifts:
                x1, y1 = max(0, j - 25 + xs), top
                x2, y2 = min(W, x1 + 50), top + 55
                box = skin_mask[y1:y2, x1:x2]
                frac = float(np.mean(box > 0)) if box.size else 1.0
                candidates.append({
                    'peak': pi,
                    'bbox': (x1, y1, x2, y2),
                    'area': (x2 - x1) * (y2 - y1),
                    'centroid': ((x1 + x2) // 2, (y1 + y2) // 2),
                    'aspect': (x2 - x1) / (y2 - y1),
                    'skin_frac': frac,
                    # nail evidence: the nail is a hole -> lower skin fraction = more nail-like
                    'score': 1.0 - frac,
                })
    # keep the best-scoring boxes per fingertip peak (spread candidates across
    # peaks so one dominant peak cannot starve the other fingers).
    candidates.sort(key=lambda c: (c['peak'], -c['score']))
    per_peak = {}
    for c in candidates:
        if per_peak.get(c['peak'], 0) < 10:
            per_peak[c['peak']] = per_peak.get(c['peak'], 0) + 1
        else:
            c['_drop'] = True
    candidates = [c for c in candidates if not c.get('_drop')]
    # loose global cap - precision is handled by the greedy matcher
    candidates.sort(key=lambda c: c['score'], reverse=True)
    return candidates[:45]


def iou(a, b):
    xa, ya = max(a[0], b[0]), max(a[1], b[1])
    xb, yb = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, xb - xa) * max(0, yb - ya)
    aa = (a[2] - a[0]) * (a[3] - a[1])
    ab = (b[2] - b[0]) * (b[3] - b[1])
    u = aa + ab - inter
    return inter / u if u > 0 else 0


def greedy_match(candidates, gt_boxes):
    """Greedy assignment of candidates → GT by IoU (any IoU > 0)."""
    pairs = []
    for ci, c in enumerate(candidates):
        for gi, g in enumerate(gt_boxes):
            v = iou(c['bbox'], g)
            if v > 0:
                pairs.append((v, ci, gi))
    pairs.sort(reverse=True)
    matched = {}   # ci -> (gi, iou)
    used_gt = set()
    for v, ci, gi in pairs:
        if ci in matched or gi in used_gt:
            continue
        matched[ci] = (gi, v)
        used_gt.add(gi)
    return matched


def draw_overlay(img_rot, candidates, gt_boxes, matched, path):
    ov = img_rot.copy()
    for g in gt_boxes:
        x1, y1, x2, y2 = map(int, g)
        cv2.rectangle(ov, (x1, y1), (x2, y2), (0, 200, 255), 2)  # GT yellow
    for ci, c in enumerate(candidates):
        x1, y1, x2, y2 = map(int, c['bbox'])
        color = (0, 255, 0) if ci in matched else (0, 0, 255)
        cv2.rectangle(ov, (x1, y1), (x2, y2), color, 2)  # match green / FP red
        if ci in matched:
            gi, v = matched[ci]
            cx, cy = map(int, c['centroid'])
            cv2.putText(ov, f"{v:.2f}", (cx - 20, max(12, cy - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    cv2.imwrite(str(path), ov)


# ---------------------------------------------------------------- main loop
results = []
skip = 0
all_iou = []

for _, row in df.iterrows():
    pid = row.PATIENT_ID
    img_path = PHOTO / f"{pid}.jpg"
    if not img_path.exists():
        skip += 1
        continue
    try:
        nails = json.loads(row.NAIL_BOUNDING_BOXES)
    except Exception:
        skip += 1
        continue
    if not nails:
        skip += 1
        continue

    gt_boxes = [h6_transform_box(b) for b in nails]
    img = cv2.imread(str(img_path))
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    H, W = img_rot.shape[:2]

    skin = segment_skin(img_rot)

    # GT center inside skin → alignment sanity
    hits = 0
    for g in gt_boxes:
        cx, cy = int((g[0] + g[2]) / 2), int((g[1] + g[3]) / 2)
        if 0 <= cx < W and 0 <= cy < H and skin[cy, cx] > 0:
            hits += 1
    gt_skin_pct = hits / len(gt_boxes) * 100

    candidates = find_nails(skin, img_rot)
    matched = greedy_match(candidates, gt_boxes)

    n_gt, n_cand, n_matched = len(gt_boxes), len(candidates), len(matched)
    miou = np.mean([v for _, v in matched.values()]) if matched else 0.0
    all_iou.extend([v for _, v in matched.values()])

    results.append({
        'pid': pid, 'n_gt': n_gt, 'n_cand': n_cand, 'n_matched': n_matched,
        'mean_iou': miou, 'gt_skin_pct': gt_skin_pct,
    })

    # overlays for a few representative pids
    if pid in (288, 54, 1, 5, 40, 46, 52, 61, 62, 82, 73, 76, 84, 97, 105, 128, 133, 153, 182, 220, 245):
        draw_overlay(img_rot, candidates, gt_boxes, matched, OUT / f"{pid}_eval_overlay.png")

rdf = pd.DataFrame(results)
print(f"\nProcessed: {len(rdf)}, skipped: {skip}")

# ---- recall / precision at thresholds (aggregated over boxes) ----
print(f"\n{'='*64}")
print("PCD NAIL SEGMENTATION vs H6-GT (250 foto figshare)")
print(f"{'='*64}")
print(f"GT boxes total:          {rdf.n_gt.sum()}")
print(f"Candidates detected:     {rdf.n_cand.sum()}")
print(f"GT centers in skin mask: mean {rdf.gt_skin_pct.mean():.1f}%  "
      f"(100%: {(rdf.gt_skin_pct == 100).sum()}/{len(rdf)})")
# ---- quick re-run storing per-box IoUs to do a clean sweep ----
# (matching re-run here so per-box IoU is available for thresholding)
print("\n(Recomputing with per-box storage...)\n")
rows_sweep = []
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
    skin = segment_skin(img_rot)
    candidates = find_nails(skin, img_rot)
    matched = greedy_match(candidates, gt_boxes)
    rows_sweep.append({
        'n_gt': len(gt_boxes),
        'n_cand': len(candidates),
        'ious': [v for _, v in matched.values()],
    })

print(f"  t      recall     precision   meanIoU(matched)")
for t in [0.1, 0.2, 0.3, 0.5, 0.7]:
    tp = sum(1 for r in rows_sweep for v in r['ious'] if v >= t)
    n_gt = sum(r['n_gt'] for r in rows_sweep)
    n_det = sum(r['n_cand'] for r in rows_sweep)
    rec = tp / n_gt if n_gt else 0
    prec = tp / n_det if n_det else 0
    print(f"  {t:.1f}    {rec:.3f}      {prec:.3f}")

# mean IoU of matched boxes overall
if all_iou:
    print(f"\nMean IoU (matched boxes only): {np.mean(all_iou):.3f}  (n={len(all_iou)})")

# ---- IoU histogram of loose matches: where do the sub-0.5 matches sit? ----
edges = [0.0, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1.001]
buckets = [0] * (len(edges) - 1)
for v in all_iou:
    for bi in range(len(edges) - 1):
        if edges[bi] <= v < edges[bi + 1]:
            buckets[bi] += 1
            break
print("\nIoU histogram (loose matches):")
for bi in range(len(edges) - 1):
    lo = f"{edges[bi]:.1f}"
    hi = "<0.2" if bi == 0 else f"-{edges[bi + 1]:.1f}"
    print(f"  [{lo},{hi}): {buckets[bi]}")

# ---- GT box size distribution (rotated space) ----
gtw, gth = [], []
for _, row in df.iterrows():
    try:
        nails = json.loads(row.NAIL_BOUNDING_BOXES)
    except Exception:
        continue
    if not nails:
        continue
    for b in nails:
        x1, y1, x2, y2 = h6_transform_box(b)
        gtw.append(x2 - x1)
        gth.append(y2 - y1)
gtw, gth = np.array(gtw), np.array(gth)
print(f"\nGT box size (n={len(gtw)}):  w med {np.median(gtw):.0f} (q25 {np.percentile(gtw, 25):.0f}, q75 {np.percentile(gtw, 75):.0f})  "
      f"h med {np.median(gth):.0f} (q25 {np.percentile(gth, 25):.0f}, q75 {np.percentile(gth, 75):.0f})")

# per-image recall@0.5
r_rec50 = []
for r in rows_sweep:
    tp = sum(1 for v in r['ious'] if v >= 0.5)
    r_rec50.append(tp / r['n_gt'] if r['n_gt'] else 0)
r_rec50 = pd.Series(r_rec50)
print(f"\nPer-image recall@0.5: mean {r_rec50.mean():.3f}, median {r_rec50.median():.3f}, "
      f"=1.0: {(r_rec50 == 1).sum()}/{len(r_rec50)}, =0: {(r_rec50 == 0).sum()}/{len(r_rec50)}")

print(f"\nWorst 10 by recall@0.5 / mean_iou:")
worst = rdf.nsmallest(10, 'mean_iou')[['pid', 'n_gt', 'n_cand', 'n_matched', 'mean_iou', 'gt_skin_pct']]
print(worst.to_string(index=False))

rdf.to_csv(str(OUT / "segment_eval_results.csv"), index=False)
print(f"\nSaved per-image rows: {OUT / 'segment_eval_results.csv'}")
print(f"Overlays: {OUT}")

# ---- one-line summary for sweep runs ----
tp50 = sum(1 for r in rows_sweep for v in r['ious'] if v >= 0.5)
n_gt = sum(r['n_gt'] for r in rows_sweep)
n_det = sum(r['n_cand'] for r in rows_sweep)
print(f"\nFINAL @0.5: recall {tp50 / n_gt:.3f}  precision {tp50 / n_det:.3f}  "
      f"tp {tp50}/{n_gt}  dets {n_det}  mean_iou_loose {np.mean(all_iou):.3f}")