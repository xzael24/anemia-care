"""Train ulang RandomForest feature-based (reproduksi baseline) + simpan joblib.

Data: capstone/data/processed/{train,val,test}.csv + images/ (mirror dataset lokal).
Prosedur identik baseline:
  1. fitur 33D per foto, collapse (mean) per pasien -> unit analisis = pasien
  2. RandomForest(n_estimators=300, random_state=42)
  3. eval val & test (threshold 0.5), CV-AUC GroupKFold pada train
Output: rf_model.joblib + rf_report.json di folder ini.
"""
import json
import sys
from pathlib import Path

import cv2
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GroupKFold, cross_val_score

SEED = 42
HERE = Path(__file__).resolve().parent
PROC = HERE.parent / "capstone" / "data" / "processed"
IMGS = PROC / "images"

sys.path.insert(0, str(HERE))
from features import extract_features  # noqa: E402


def load_split(df: pd.DataFrame):
    """-> X (n_pasien x 33), y, patient_ids (fitur dirata-rata per pasien)."""
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
        y.append(grp["y"].iloc[0])
        ids.append(pid)
    return np.array(X), np.array(y), np.array(ids)


def report_metrics(name: str, y_true, y_prob, threshold: float = 0.5):
    y_pred = (y_prob >= threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    sens = tp / (tp + fn) if tp + fn else 0.0
    spec = tn / (tn + fp) if tn + fp else 0.0
    row = dict(
        acc=accuracy_score(y_true, y_pred),
        sens=sens,
        spec=spec,
        prec=precision_score(y_true, y_pred, zero_division=0),
        f1=f1_score(y_true, y_pred, zero_division=0),
        auc=roc_auc_score(y_true, y_prob),
        prauc=average_precision_score(y_true, y_prob),
    )
    print(f"[{name}] " + " ".join(f"{k}={v:.3f}" for k, v in row.items()))
    return row


def main():
    np.random.seed(SEED)
    train = pd.read_csv(PROC / "train.csv")
    val = pd.read_csv(PROC / "val.csv")
    test = pd.read_csv(PROC / "test.csv")
    for df in (train, val, test):
        df["y"] = (df["label"] == "anemic").astype(int)

    print("load fitur (collapse per pasien)...")
    Xtr, ytr, ptr = load_split(train)
    Xval, yval, _ = load_split(val)
    Xte, yte, _ = load_split(test)
    print(f"feature matrix: train {Xtr.shape} | val {Xval.shape} | test {Xte.shape}")

    gkf = GroupKFold(n_splits=5)
    aucs = cross_val_score(
        RandomForestClassifier(n_estimators=300, random_state=SEED, n_jobs=-1),
        Xtr, ytr, groups=ptr, cv=gkf, scoring="roc_auc", n_jobs=1,
    )
    print(f"CV-AUC (GroupKFold) RandomForest: {aucs.round(3)} -> mean {np.mean(aucs):.3f}")

    rf = RandomForestClassifier(n_estimators=300, random_state=SEED, n_jobs=-1)
    rf.fit(Xtr, ytr)

    rows = {}
    rows["val"] = report_metrics("RF val", yval, rf.predict_proba(Xval)[:, 1])
    rows["test"] = report_metrics("RF test", yte, rf.predict_proba(Xte)[:, 1])

    joblib.dump(rf, HERE / "rf_model.joblib")
    report = {"cv_auc_mean": float(np.mean(aucs)), "rows": rows, "n_estimators": 300}
    (HERE / "rf_report.json").write_text(json.dumps(report, indent=2))
    print("model ->", HERE / "rf_model.joblib")


if __name__ == "__main__":
    main()