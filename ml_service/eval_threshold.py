"""Eksperimen 1 (murah): cari threshold proba di VALIDATION yang memenuhi
recall anemia >= 0.85, lalu evaluasi jujur di TEST.

Output: ringkasan trade-off sens/spec/prec per threshold; threshold terpilih
dievaluasi di test. Unit analisis = pasien (mean fitur), identik train.py.
"""
import json
import sys
from pathlib import Path

import cv2
import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import (
    confusion_matrix,
    precision_score,
    recall_score,
    roc_auc_score,
)

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
    return np.array(X), np.array(y)


def main():
    rf = joblib.load(HERE / "rf_model.joblib")
    val = pd.read_csv(PROC / "val.csv")
    test = pd.read_csv(PROC / "test.csv")
    for df in (val, test):
        df["y"] = (df["label"] == "anemic").astype(int)

    Xval, yval = load_split(val)
    Xte, yte = load_split(test)
    pval = rf.predict_proba(Xval)[:, 1]
    pte = rf.predict_proba(Xte)[:, 1]
    print(f"pasien: val {Xval.shape[0]} | test {Xte.shape[0]}")

    print("\n=== Threshold scan (VAL, recall anemia >= 0.85) ===")
    best = None
    for t in np.arange(0.05, 0.96, 0.01):
        yp = (pval >= t).astype(int)
        sens = recall_score(yval, yp)
        if sens >= 0.85:
            tn, fp, fn, tp = confusion_matrix(yval, yp).ravel()
            spec = tn / (tn + fp)
            prec = precision_score(yval, yp, zero_division=0)
            print(f"t={t:.2f} sens={sens:.3f} spec={spec:.3f} prec={prec:.3f}")
            if best is None or prec > best[1]:
                best = (t, prec, sens, spec)

    if best is None:
        print("!! recall 0.85 tidak tercapai di val dengan model ini")
        return
    t, prec, sens, spec = best
    print(f"\nPilih threshold val t={t:.2f} (prec tertinggi di antara sens>=0.85)")

    # Evaluasi jujur di TEST
    yp = (pte >= t).astype(int)
    tn, fp, fn, tp = confusion_matrix(yte, yp).ravel()
    print("\n=== TEST pada t terpilih ===")
    print(f"sens(recall)={tp/(tp+fn):.3f} spec={tn/(tn+fp):.3f} "
          f"prec={tp/(tp+fp):.3f} auc={roc_auc_score(yte, pte):.3f}")
    print(f"confusion: TP={tp} FN={fn} FP={fp} TN={tn}")

    # Kontras: threshold default 0.5
    yp05 = (pte >= 0.5).astype(int)
    tn5, fp5, fn5, tp5 = confusion_matrix(yte, yp05).ravel()
    print(f"\n[basis] TEST @0.5 : sens={tp5/(tp5+fn5):.3f} spec={tn5/(tn5+fp5):.3f} "
          f"prec={tp5/(tp5+fp5):.3f}")


if __name__ == "__main__":
    main()