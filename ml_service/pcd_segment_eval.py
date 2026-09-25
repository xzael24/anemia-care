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

from pcd_core import (greedy_match, h6_transform_box, iou, find_nails,
                      find_nails_dt, segment_skin, top_edge)

PHOTO = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo")
META = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv")
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\pcd_eval")
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(META)
print(f"Total rows: {len(df)}")


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