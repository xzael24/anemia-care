"""Eksperimen 2 (retrain): RandomForest dengan class_weight (balanced /
balanced_subsample) — tiap varian dicari threshold terbaik di VALIDATION
(recall anemia >= 0.85, pilih prec tertinggi), lalu evaluasi jujur di TEST.

Tujuan: recall >= 0.85 di test dengan spesifisitas/precision setinggi mungkin
(lebih baik dari threshold-only 0.39 -> sens 0.877/spec 0.614).
"""
import sys
import time
from pathlib import Path

import cv2
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import confusion_matrix, precision_score, recall_score, roc_auc_score

SEED = 42
HERE = Path(__file__).resolve().parent
PROC = HERE.parent / "capstone" / "data" / "processed"
IMGS = PROC / "images"
sys.path.insert(0, str(HERE))
from features import extract_features  # noqa: E402


def load_split(df: pd.DataFrame):
    X, y, ids = [], [], []
    for pid, grp in df.groupby("patient_id"):
        feats = []
        for fn in grp["image_id"]:
            img = cv2.imread(str(IMGS / fn))
            if img is None:
                continue
            feats.append(extract_features(cv2.cvtColor(img, cv2.COLOR_BGR2RGB)))
        if not feats:
            continue
        X.append(np.mean(feats, axis=0))
        y.append(int(grp["y"].iloc[0]))
        ids.append(pid)
    return np.array(X), np.array(y), np.array(ids)


def threshold_val(p, y):
    """Threshold di VALIDATION: recall >= 0.85, pilih prec tertinggi."""
    best = None
    for t in np.arange(0.05, 0.96, 0.01):
        yp = (p >= t).astype(int)
        sens = recall_score(y, yp)
        if sens >= 0.85:
            prec = precision_score(y, yp, zero_division=0)
            if best is None or prec > best[1]:
                best = (t, prec, sens)
    return best


def main():
    train = pd.read_csv(PROC / "train.csv")
    val = pd.read_csv(PROC / "val.csv")
    test = pd.read_csv(PROC / "test.csv")
    for df in (train, val, test):
        df["y"] = (df["label"] == "anemic").astype(int)

    Xtr, ytr, ptr = load_split(train)
    Xval, yval, _ = load_split(val)
    Xte, yte, _ = load_split(test)

    variants = [
        ("rf_none", None),
        ("rf_balanced", "balanced"),
        ("rf_bal_subset", "balanced_subsample"),
    ]
    results = []
    for name, cw in variants:
        t0 = time.time()
        rf = RandomForestClassifier(
            n_estimators=300, random_state=SEED, n_jobs=-1, class_weight=cw
        )
        rf.fit(Xtr, ytr)
        pval = rf.predict_proba(Xval)[:, 1]
        pte = rf.predict_proba(Xte)[:, 1]
        sel = threshold_val(pval, yval)
        if sel is None:
            print(f"[{name}] recall 0.85 tidak tercapai di val")
            continue
        t, _, _ = sel
        yp = (pte >= t).astype(int)
        tn, fp, fn, tp = confusion_matrix(yte, yp).ravel()
        sens = tp / (tp + fn)
        spec = tn / (tn + fp)
        prec = tp / (tp + fp)
        rows = dict(
            variant=name, t=round(t, 2), sens=round(sens, 3), spec=round(spec, 3),
            prec=round(prec, 3), auc=round(roc_auc_score(yte, pte), 3),
            tp=tp, fn=fn, fp=fp, tn=tn, seconds=round(time.time() - t0, 1),
        )
        results.append(rows)
        print(f"[{name}] TEST t={t:.2f} sens={sens:.3f} spec={spec:.3f} "
              f"prec={prec:.3f} auc={roc_auc_score(yte, pte):.3f} "
              f"TP={tp} FN={fn} FP={fp} TN={tn} ({time.time()-t0:.0f}s)")

    print("\n=== bandingkan (target: recall>=0.85, spec & prec tertinggi) ===")
    for r in sorted(results, key=lambda x: (-x["spec"], -x["prec"])):
        print(f"{r['variant']}: t={r['t']} sens={r['sens']} spec={r['spec']} "
              f"prec={r['prec']} auc={r['auc']}")


if __name__ == "__main__":
    main()