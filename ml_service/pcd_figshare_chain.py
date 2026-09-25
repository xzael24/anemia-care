"""Rantai end-to-end: foto tangan penuh figshare -> PCD kuku -> crop -> fitur 33D -> RF.

Menjawab: apakah pipeline (PCD deteksi kuku + RandomForest kaggle close-up) bisa
memisahkan anemia vs normal pada foto tangan penuh (out-of-domain)?

Varian yang diukur per pasien (n=250, Hb g/L dari metadata):
  GT-mean/median/max  : crop pakai bbox ground-truth (oracle localization)
  PCD-mean/median/max : crop pakai top-2-per-peak box dari find_nails(PCD)
  RAW                 : foto penuh tanpa crop (baseline referensi lama)

Metrik per varian: Spearman rho(prob, Hb), AUC (Hb<120 anemia — cut-off WHO tanpa
info jenis kelamin), mean prob kelompok anemi vs normal.
"""
import joblib
import numpy as np
import pandas as pd
import cv2
from scipy import stats

from app import MODEL_PATH, THRESHOLD
from features import extract_features
from pcd_core import h6_transform_box, find_nails, segment_skin

PHOTO = r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\photo"
META = r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw\figshare-nature-photo-hb\metadata.csv"
OUT = r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\pcd_chain"
import os
import sys
os.makedirs(OUT, exist_ok=True)

MODE = sys.argv[1] if len(sys.argv) > 1 else 'all'   # all | filter | top1 | top3 | top4
print(f"MODE={MODE}")

if MODE == 'filter':
    KEEP_K, DO_FILTER = 2, True
elif MODE == 'top1':
    KEEP_K, DO_FILTER = 1, False
elif MODE in ('top3', 'top4'):
    KEEP_K, DO_FILTER = int(MODE[3:]), False
else:  # 'all'
    KEEP_K, DO_FILTER = 2, False

model = joblib.load(MODEL_PATH)
df = pd.read_csv(META)


def crop_proba(img_bgr, box):
    """Crop -> resize 224 LANCZOS -> RGB -> fitur 33D -> proba RF (replika serving)."""
    x1, y1, x2, y2 = map(int, box)
    x1, y1 = max(0, x1), max(0, y1)
    crop = img_bgr[y1:y2, x1:x2]
    if crop.size == 0:
        return None
    rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
    rgb = cv2.resize(rgb, (224, 224), interpolation=cv2.INTER_LANCZOS4)
    feats = extract_features(rgb).reshape(1, -1)
    return float(model.predict_proba(feats)[0, 1])


rows = []
for _, row in df.iterrows():
    pid = row.PATIENT_ID
    hb = float(row.HB_LEVEL_GperL)
    img_path = os.path.join(PHOTO, f"{pid}.jpg")
    if not os.path.exists(img_path):
        continue
    img = cv2.imread(img_path)
    img_rot = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    gt_boxes = [h6_transform_box(b) for b in eval(row.NAIL_BOUNDING_BOXES)]

    # oracle: crop GT boxes
    gt_probs = [p for p in (crop_proba(img_rot, b) for b in gt_boxes) if p is not None]
    # raw full image (reference baseline)
    raw_prob = None
    full = cv2.cvtColor(img_rot, cv2.COLOR_BGR2RGB)
    full = cv2.resize(full, (224, 224), interpolation=cv2.INTER_LANCZOS4)
    raw_prob = float(model.predict_proba(extract_features(full).reshape(1, -1))[0, 1])

    # PCD inference: top-K per peak by score (detector's own best boxes)
    skin = segment_skin(img_rot)
    cands = find_nails(skin, img_rot)
    if DO_FILTER:
        # drop pure-background boxes (paper / table, little skin inside)
        cands = [c for c in cands if c['skin_frac'] >= 0.25]
    cands.sort(key=lambda c: (c['peak'], -c['score']))
    per_peak = {}
    pcd_keep = []
    for c in cands:
        if per_peak.get(c['peak'], 0) < KEEP_K:
            per_peak[c['peak']] = per_peak.get(c['peak'], 0) + 1
            pcd_keep.append(c)
    pcd_probs = [p for p in (crop_proba(img_rot, c['bbox']) for c in pcd_keep) if p is not None]

    rows.append({
        'pid': pid, 'hb': hb,
        'n_gt_prob': len(gt_probs), 'n_pcd_prob': len(pcd_probs),
        'gt_mean': float(np.mean(gt_probs)) if gt_probs else np.nan,
        'gt_median': float(np.median(gt_probs)) if gt_probs else np.nan,
        'gt_max': float(np.max(gt_probs)) if gt_probs else np.nan,
        'pcd_mean': float(np.mean(pcd_probs)) if pcd_probs else np.nan,
        'pcd_median': float(np.median(pcd_probs)) if pcd_probs else np.nan,
        'pcd_max': float(np.max(pcd_probs)) if pcd_probs else np.nan,
        'raw': raw_prob,
    })

rdf = pd.DataFrame(rows)
csv_name = "chain_results.csv" if MODE == 'all' else f"chain_{MODE}.csv"
rdf.to_csv(os.path.join(OUT, csv_name), index=False)
print(f"processed: {len(rdf)} patients, used {rdf.n_gt_prob.sum()} GT crops, {rdf.n_pcd_prob.sum()} PCD crops")

# ---- metrics per variant ----
ANEMIA_CUTOFF = 120.0  # g/L, WHO-ish tanpa informasi jenis kelamin
label = (rdf.hb < ANEMIA_CUTOFF).astype(int)
print(f"\nanemia (Hb<{ANEMIA_CUTOFF:.0f}): {label.sum()}/{len(rdf)}, Hb range {rdf.hb.min():.0f}-{rdf.hb.max():.0f}, median {rdf.hb.median():.0f}")

print(f"\n{'variant':<12} {'n':>4} {'rho':>7} {'p':>8} {'AUC':>6} {'prob anemi':>10} {'prob normal':>11}")
variants = ['raw', 'gt_mean', 'gt_median', 'gt_max', 'pcd_mean', 'pcd_median', 'pcd_max']
for v in variants:
    s = rdf[[v, 'hb']].dropna()
    n = len(s)
    rho, p = stats.spearmanr(s[v], s.hb)
    auc = 0.0
    mask = s.hb < ANEMIA_CUTOFF
    if mask.sum() > 0 and (mask == False).sum() > 0 and s[v].nunique() > 1:
        from sklearn.metrics import roc_auc_score
        auc = roc_auc_score(mask, s[v])
    pa = s.loc[mask, v].mean() if mask.sum() else float('nan')
    pn = s.loc[~mask, v].mean() if (~mask).sum() else float('nan')
    print(f"{v:<12} {n:>4} {rho:>7.3f} {p:>8.3g} {auc:>6.3f} {pa:>10.3f} {pn:>11.3f}")

# direction check on the two extreme patients from the earlier (invalid) crop test
for pid in (1, 2):
    r = rdf[rdf.pid == pid]
    if len(r):
        print(f"\npid {pid}: Hb {r.hb.iloc[0]:.1f}  gt_mean {r.gt_mean.iloc[0]:.3f}  "
              f"pcd_median {r.pcd_median.iloc[0]:.3f}  raw {r.raw.iloc[0]:.3f}")

# ---- sens/spec pada threshold serving (0.39) + Youden, varian utama ----
print(f"\nSens/spec pada THRESHOLD serving {THRESHOLD} (label: Hb<120):")
for v in ['gt_mean', 'pcd_mean']:
    s = rdf[['hb', v]].dropna()
    y = (s.hb < ANEMIA_CUTOFF).astype(int)
    pred = (s[v] >= THRESHOLD).astype(int)
    tp = int(((pred == 1) & (y == 1)).sum())
    fn = int(((pred == 0) & (y == 1)).sum())
    fp = int(((pred == 1) & (y == 0)).sum())
    tn = int(((pred == 0) & (y == 0)).sum())
    sens = tp / (tp + fn) if (tp + fn) else float('nan')
    spec = tn / (tn + fp) if (tn + fp) else float('nan')
    print(f"  {v:<10} sens {sens:.3f}  spec {spec:.3f}  (tp {tp} fn {fn} fp {fp} tn {tn})")