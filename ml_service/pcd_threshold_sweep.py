"""Sweep threshold untuk rantai PCD->crop->RF pada foto tangan penuh figshare.

Baca chain_results.csv (output pcd_figshare_chain.py). Cari operating point:
  - Youden (sens + spec - 1 max)
  - sens >= 0.85 dengan spec tertinggi (target KONSEP: recall anemia >= 0.85)
  - titik serving saat ini (0.39) sebagai pembanding

CATATAN: evaluasi penuh pada set tes figshare (bukan hold-out) -> angka ini
adalah ceiling empiris, bukan klaim generalisasi.
"""
import os
import numpy as np
import pandas as pd

OUT = r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\mltest\pcd_chain"
CSV = os.path.join(OUT, "chain_results.csv")
CUT = 120.0  # g/L anemia cutoff (WHO-ish, tanpa info jenis kelamin)
SERVING = 0.39

rdf = pd.read_csv(CSV)
y = (rdf.hb < CUT).astype(int)
n_an, n_norm = int(y.sum()), int((y == 0).sum())
print(f"patients: {len(rdf)}  anemia(Hb<{CUT:.0f}): {n_an}  normal: {n_norm}\n")

variants = ['raw', 'gt_mean', 'gt_median', 'gt_max', 'pcd_mean', 'pcd_median', 'pcd_max']


def sens_spec(vals, t):
    pred = (vals >= t).astype(int)
    tp = int(((pred == 1) & (y == 1)).sum())
    fn = int(((pred == 0) & (y == 1)).sum())
    fp = int(((pred == 1) & (y == 0)).sum())
    tn = int(((pred == 0) & (y == 0)).sum())
    sens = tp / (tp + fn) if (tp + fn) else float('nan')
    spec = tn / (tn + fp) if (tn + fp) else float('nan')
    ppv = tp / (tp + fp) if (tp + fp) else float('nan')
    return sens, spec, ppv, tp, fp


print(f"{'variant':<12} {'t_Youden':>8} {'sens':>6} {'spec':>6} {'t_sens>=.85':>12} {'spec@':>7} {'sens@0.39':>10} {'spec@0.39':>10}")
best_overall = None
for v in variants:
    s = rdf[[v]].dropna()
    vals = s[v].to_numpy()
    ts = np.arange(0.025, 0.975, 0.025)
    best_j, best_tj = -1e9, 0.5
    best_s85, best_t85 = -1e9, 0.5
    for t in ts:
        se, sp, _, _, _ = sens_spec(vals, t)
        if np.isnan(se) or np.isnan(sp):
            continue
        j = se + sp - 1
        if j > best_j:
            best_j, best_tj = j, t
        if se >= 0.85 and sp > best_s85:
            best_s85, best_t85 = sp, t
    sej, spj, _, _, _ = sens_spec(vals, best_tj)
    se85, sp85, _, _, _ = sens_spec(vals, best_t85)
    se0, sp0, _, _, _ = sens_spec(vals, SERVING)
    print(f"{v:<12} {best_tj:>8.3f} {sej:>6.3f} {spj:>6.3f} {best_t85:>12.3f} {sp85:>7.3f} {se0:>10.3f} {sp0:>10.3f}")
    if v in ('gt_mean', 'pcd_mean', 'pcd_median'):
        score = se85 * sp85
        if best_overall is None or score > best_overall[2]:
            best_overall = (v, best_t85, score, se85, sp85)

print(f"\nRekomendasi (sens>=0.85, spec tertinggi): {best_overall[0]} @ t={best_overall[1]:.3f} -> "
      f"sens {best_overall[3]:.3f} spec {best_overall[4]:.3f}")

# profil pcd_mean di sekitar rekomendasi
v = 'pcd_mean'
vals = rdf[v].to_numpy()
print(f"\nProfil {v} (sens/spec/ppv per threshold):")
for t in (0.20, 0.25, 0.30, 0.35, 0.39, 0.45, 0.50, 0.55):
    se, sp, ppv, tp, fp = sens_spec(vals, t)
    print(f"  t={t:.2f}: sens {se:.3f} spec {sp:.3f} ppv {ppv:.3f} (tp {tp}, fp {fp})")