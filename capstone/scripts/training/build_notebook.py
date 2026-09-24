# -*- coding: utf-8 -*-
"""
build_notebook.py — Bangun scripts/training/baselines_colab.ipynb (siap jalan di Colab).

Isi notebook (2 pendekatan yang dibandingkan untuk skrining anemia):
  A) Feature-based : persentil RGB + rasio warna + LAB + HSV per crop,
                     di-collapse per pasien (anti-leak), model LogReg/RF/GBM,
                     GroupKFold per pasien, evaluasi val+test.
  B) CNN           : MobileNetV2 transfer learning, augmentasi, sample-weight
                     (imbalance), threshold tuning di val dengan prioritas
                     SENSITIVITAS (skrining, bukan diagnosis).
  C) (opsional)     : regresi Hb (ElasticNet) khusus patients nature (Hb asli),
                     pembanding RMSE paper Yakimov 2024 (20-24 g/L).
Split sudah per-pasien dari 03_splits.py (train/val/test.csv) — notebook WAJIB
memakai split ini, TIDAK bikin split sendiri (anti bocor antar-sumber).
"""

import json
from pathlib import Path

OUT = Path(r"scripts/training/baselines_colab.ipynb")

CELLS = []


def md(src):
    CELLS.append({"cell_type": "markdown", "metadata": {}, "source": src})


def code(src):
    CELLS.append({"cell_type": "code", "execution_count": None,
                  "metadata": {}, "outputs": [], "source": src})


# ----------------------------------------------------------------------------
md("""# Baseline Training — Skrining Anemia dari Foto Kuku (Capstone Sem 5)

Dua pendekatan dibandingkan:
1. **Feature-based** — fitur warna/tekstur per-crop kuku (persentil RGB, rasio
   R/(G+B), LAB a*, HSV), di-*collapse* per pasien → LogReg / RandomForest /
   GradientBoosting. Validasi pakai *GroupKFold per pasien* (anti bocor).
2. **CNN transfer learning** — MobileNetV2 (weights ImageNet), augmentasi,
   sample-weight untuk imbalance, threshold tuning di validasi dengan prioritas
   **sensitivitas (recall anemia)** karena output = *indikasi awal skrining*,
   BUKAN diagnosis.

Opsional: regresi Hb (ElasticNet) khusus subset `nature` yang punya Hb asli —
pembanding paper asli Yakimov et al. 2024 (RMSE ~20–24 g/L).

> ⚠️ DISCLAIMER: semua model di notebook ini untuk **skrining indikasi awal**.
> Bukan pengganti pemeriksaan laboratorium / diagnosis medis.
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 1) Setup: install & import
# =============================================================================
%pip install -q numpy pandas pillow opencv-python-headless scikit-learn tensorflow tqdm

import json, os, zipfile, shutil
from pathlib import Path

import numpy as np
import pandas as pd
import cv2
from tqdm.auto import tqdm

import tensorflow as tf
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression, ElasticNetCV
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import GroupKFold, cross_val_score
from sklearn.metrics import (accuracy_score, recall_score, precision_score,
                             f1_score, roc_auc_score, average_precision_score,
                             confusion_matrix, r2_score, mean_squared_error)
from sklearn.utils.class_weight import compute_class_weight

SEED = 42
np.random.seed(SEED)
tf.random.set_seed(SEED)

print("OK")
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 2) Lokasi & ekstrak dataset (auto: /content -> Drive -> upload manual)
# =============================================================================
ZIP_NAME = "anemia_nail_dataset_v1.zip"
DATA_ROOT = Path("/content/anemia_nail_dataset_v1")
IMGS = DATA_ROOT / "images"


def extract_zip(zip_path: Path):
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(zip_path.parent)
    assert IMGS.exists(), "Struktur zip salah: harus berisi folder anemia_nail_dataset_v1/images/"


def locate_or_upload():
    if IMGS.exists() and any(IMGS.glob("*.jpg")):
        print("Dataset sudah siap:", DATA_ROOT)
        return
    zips = list(Path("/content").glob("*" + ZIP_NAME))
    if zips:
        extract_zip(zips[0]); print("Zip ditemukan di /content:", zips[0]); return
    drive_root = Path("/content/drive/MyDrive")
    if drive_root.exists():
        zips = list(drive_root.rglob(ZIP_NAME))
        if zips:
            extract_zip(zips[0]); print("Zip ditemukan di Drive:", zips[0]); return
        folders = [c for c in drive_root.rglob("anemia_nail_dataset_v1") if (c / "images").exists()]
        if folders:
            shutil.copytree(folders[0], DATA_ROOT, dirs_exist_ok=True)
            print("Folder dataset di Drive:", folders[0]); return
    from google.colab import files
    print("Upload file berikut via tombol di UI Colab:", ZIP_NAME)
    up = files.upload()
    if ZIP_NAME in up:
        extract_zip(Path("/content") / ZIP_NAME)
    else:
        raise RuntimeError("Zip tidak ter-upload. Pakai Google Drive atau tombol upload.")


locate_or_upload()
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 3) Load split (sudah per-pasien dari 03_splits.py) + sanity check
# =============================================================================
train = pd.read_csv(DATA_ROOT / "train.csv")
val   = pd.read_csv(DATA_ROOT / "val.csv")
test  = pd.read_csv(DATA_ROOT / "test.csv")

for df in (train, val, test):
    df["filename"] = df["image_id"]
    df["y"] = (df["label"] == "anemic").astype(int)

# anti bocor: satu pasien tidak boleh ada di >1 split
tp, vp, tsp = set(train.patient_id), set(val.patient_id), set(test.patient_id)
assert tp.isdisjoint(vp) and tp.isdisjoint(tsp) and vp.isdisjoint(tsp), "BOCOR: pasien lintas split!"
missing = set(train.filename) | set(val.filename) | set(test.filename)
assert missing <= {p.name for p in IMGS.glob("*.jpg")}, "Ada image_id tanpa file!"

for name, df in (("train", train), ("val", val), ("test", test)):
    print(f"{name:>5}: {len(df):>4} gambar | {df.patient_id.nunique():>3} pasien | "
          f"label={dict(df.label.value_counts())}")
print("Pasien antar-split tidak ada yang tumpang tindih -> OK")
""")

# ----------------------------------------------------------------------------
md("""## A) Feature-based
Fitur per crop kuku (224×224) lalu dirata-rata per pasien (pasien = unit analisis,
karena split sudah per-pasien). Validasi: GroupKFold(5) per pasien pada data train.""")
# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 4) Ekstraksi fitur & collapse per pasien
# =============================================================================
PCTS = [5, 15, 25, 50, 75, 85, 95]


def extract_features(rgb: np.ndarray) -> np.ndarray:
    # 33 fitur: persentil RGB (21) + rasio R/G+B (3) + LAB (5) + HSV (2) + gray (2)
    f = np.float32(rgb) + 1.0
    R, G, B = f[..., 0], f[..., 1], f[..., 2]
    feats = []
    for ch in range(3):
        feats.extend(np.percentile(rgb[..., ch], PCTS))          # 21
    feats.extend([np.mean(R / (G + B)), np.mean(G / (R + B)), np.mean(B / (R + G))])  # 3
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    feats.extend([lab[..., 0].mean(), lab[..., 1].mean(), lab[..., 2].mean(),
                  lab[..., 1].std(), lab[..., 2].std()])          # 5
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    feats.extend([hsv[..., 1].mean(), hsv[..., 2].mean()])        # 2
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    feats.extend([gray.mean(), gray.std()])                       # 2
    return np.array(feats, dtype=np.float32)                      # total 33


def load_features(df: pd.DataFrame):
    # -> X (n_pasien x 33), y, patient_ids (fitur dirata-rata per pasien)
    X, y, ids = [], [], []
    for pid, grp in tqdm(df.groupby("patient_id"), desc="features"):
        feats = []
        for fn in grp["filename"]:
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


Xtr_f, ytr_f, ptr_f = load_features(train)
Xval_f, yval_f, pval_f = load_features(val)
Xte_f, yte_f, pte_f = load_features(test)
print(f"feature matrix: train {Xtr_f.shape} | val {Xval_f.shape} | test {Xte_f.shape}")
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 5) Feature-based: GroupKFold per pasien + evaluasi
# =============================================================================
def report_metrics(name, y_true, y_prob, threshold=0.5, err=None):
    y_pred = (y_prob >= threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    sens = tp / (tp + fn) if tp + fn else 0.0
    spec = tn / (tn + fp) if tn + fp else 0.0
    row = dict(acc=accuracy_score(y_true, y_pred), sens=sens, spec=spec,
               prec=precision_score(y_true, y_pred, zero_division=0),
               f1=f1_score(y_true, y_pred, zero_division=0),
               auc=roc_auc_score(y_true, y_prob), prauc=average_precision_score(y_true, y_prob))
    if err is not None:
        row["err"] = err
    print("[{:<14}] ".format(name) + " ".join(f"{k}={v:.3f}" for k, v in row.items()))
    return row


MODELS = {
    "LogReg": make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000)),
    "RandomForest": RandomForestClassifier(n_estimators=300, random_state=SEED, n_jobs=-1),
    "GradientBoosting": GradientBoostingClassifier(random_state=SEED),
}

# 1) pilih model via GroupKFold (per pasien) pada train
gkf = GroupKFold(n_splits=5)
cv_scores = {}
for name, m in MODELS.items():
    aucs = cross_val_score(m, Xtr_f, ytr_f, groups=ptr_f, cv=gkf, scoring="roc_auc", n_jobs=1)
    cv_scores[name] = float(np.mean(aucs))
    print(f"CV-AUC (GroupKFold) {name:<14}: {aucs.round(3)} -> mean {np.mean(aucs):.3f}")
best_f = max(cv_scores, key=cv_scores.get)
print("Model feature-based terbaik:", best_f)

# 2) evaluasi semua model di val & test
rows = {}
for name, m in MODELS.items():
    m.fit(Xtr_f, ytr_f)
    for split_name, X, y in (("val", Xval_f, yval_f), ("test", Xte_f, yte_f)):
        rows[f"{name}|{split_name}"] = report_metrics(f"{name} {split_name}", y, m.predict_proba(X)[:, 1])
""")

# ----------------------------------------------------------------------------
md("""## B) CNN — MobileNetV2 transfer learning
- Input 224×224, augmentasi ringan (flip, brightness, contrast), sample-weight
  untuk imbalance kelas (anemia minoritas).
- Threshold keputusan di-*tune di val* dengan prioritas **sensitivitas
  (spec ≥ 0,50)** — karena output skrining: lebih baik false positive dikirim
  periksa lab daripada anemia terlewat.
- Hasil akhir dievaluasi di **test** (pasien yang tidak pernah dilihat).""")
# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 6) Load semua gambar ke array (2907 x 224x224x3 ~ 437MB, ok di Colab)
# =============================================================================
def load_split(df: pd.DataFrame):
    X = np.zeros((len(df), 224, 224, 3), np.uint8)
    for i, fn in enumerate(tqdm(df["filename"], desc="load")):
        img = cv2.imread(str(IMGS / fn))
        if img is not None:
            X[i] = cv2.cvtColor(cv2.resize(img, (224, 224)), cv2.COLOR_BGR2RGB)
    return X, df["y"].to_numpy()


Xtr, ytr = load_split(train)
Xval, yval = load_split(val)
Xte, yte = load_split(test)

cw = compute_class_weight("balanced", classes=np.array([0, 1]), y=ytr)
sw = np.where(ytr == 1, cw[1], cw[0]).astype(np.float32)
print("class_weight:", dict(zip([0, 1], cw.round(2))))
print("Xtr:", Xtr.shape, "| ytr anemic:", int(ytr.sum()), "/", len(ytr))
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 7) Definisi model + dataset pipeline
# =============================================================================
def make_model():
    base = tf.keras.applications.MobileNetV2(weights="imagenet",
                                             include_top=False,
                                             input_shape=(224, 224, 3))
    base.trainable = False
    x = tf.keras.layers.GlobalAveragePooling2D()(base.output)
    x = tf.keras.layers.Dropout(0.3)(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid")(x)
    return tf.keras.Model(base.input, out)


def augment(x, y, w):
    x = tf.image.random_flip_left_right(x)
    x = tf.image.random_brightness(x, 0.10)
    x = tf.image.random_contrast(x, 0.9, 1.1)
    return x, y, w


BATCH = 32


def make_ds(X, y, w=None, augment_flg=False, shuffle=False):
    if w is None:
        d = tf.data.Dataset.from_tensor_slices((X, y))
    else:
        d = tf.data.Dataset.from_tensor_slices((X, y, w))
    if augment_flg:
        d = d.map(augment, num_parallel_calls=tf.data.AUTOTUNE)
    if shuffle:
        d = d.shuffle(len(X))
    return d.batch(BATCH).prefetch(tf.data.AUTOTUNE)


train_ds = make_ds(Xtr, ytr, sw, augment_flg=True, shuffle=True)
val_ds = make_ds(Xval, yval)
test_ds = make_ds(Xte, yte)

EPOCHS = 20
model = make_model()
model.compile(tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy",
              metrics=["accuracy", tf.keras.metrics.Recall(name="recall"),
                       tf.keras.metrics.Precision(name="precision"),
                       tf.keras.metrics.AUC(name="auc")])
callbacks = [tf.keras.callbacks.EarlyStopping(monitor="val_auc", mode="max",
                                              patience=4, restore_best_weights=True)]
model.summary()
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 8) Training CNN
# =============================================================================
history = model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS,
                    callbacks=callbacks, verbose=1)

# kurva loss/auc ringkas
import matplotlib.pyplot as plt
fig, axes = plt.subplots(1, 2, figsize=(11, 3.5))
for ax, key in zip(axes, ("loss", "auc")):
    ax.plot(history.history[key], label="train")
    ax.plot(history.history["val_" + key], label="val")
    ax.set_title(key)
    ax.legend()
plt.tight_layout()
plt.show()
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 9) Evaluasi CNN + threshold tuning (prioritas SENSITIVITAS)
# =============================================================================
pval_cnn = model.predict(val_ds, verbose=0).ravel()
pte_cnn = model.predict(test_ds, verbose=0).ravel()

# cari threshold di val: sens maksimum dengan spec >= 0.50
best = None
for th in np.arange(0.10, 0.95, 0.05):
    sens = recall_score(yval, pval_cnn >= th)
    spec = recall_score(yval, pval_cnn >= th, pos_label=0)
    if spec >= 0.50 and (best is None or sens > best[1]):
        best = (round(float(th), 2), sens, spec)
print("threshold terpilih (val):", best)
th_cnn = best[0] if best else 0.5

rows_cnn = {}
rows_cnn["val@0.5"] = report_metrics("CNN val @0.5", yval, pval_cnn)
rows_cnn["val@th"] = report_metrics("CNN val @th", yval, pval_cnn, threshold=th_cnn)
rows_cnn["test@th"] = report_metrics("CNN test @th", yte, pte_cnn, threshold=th_cnn)

model.save("/content/anemia_model_v1.keras")
print("model tersimpan:", "/content/anemia_model_v1.keras", "| threshold:", th_cnn)
""")

# ----------------------------------------------------------------------------
md("""## C) (Opsional) Regresi Hb — subset `nature` (Hb asli tersedia)
Pembanding paper Yakimov et al. 2024 (**RMSE ~20–24 g/L**). Pakai fitur yang
sama, model ElasticNet, evaluasi per-pasien pada split test.""")
# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 10) Regresi Hb (nature saja; collapse fitur per pasien)
# =============================================================================
alldf = pd.concat([train, val, test], ignore_index=True)
nat = alldf[alldf["source"] == "nature"].copy()

Xnat, _, pnat = load_features(nat)
hb_pat = nat.groupby("patient_id")["hb_g_dl"].first()
split_pat = nat.groupby("patient_id")["split"].first()

hb_pat = hb_pat.loc[pnat.tolist()]          # sejajarkan urutan dengan Xnat
split_pat = split_pat.loc[pnat.tolist()]

Xr_tr = Xnat[split_pat.isin(["train", "val"])]
yr_tr = hb_pat[split_pat.isin(["train", "val"])].to_numpy()
Xr_te = Xnat[split_pat == "test"]
yr_te = hb_pat[split_pat == "test"].to_numpy()

reg = make_pipeline(StandardScaler(),
                    ElasticNetCV(l1_ratio=[0.01, 0.1, 0.5, 0.9, 0.99],
                                 cv=5, max_iter=10000, random_state=SEED))
reg.fit(Xr_tr, yr_tr)

pred_te = reg.predict(Xr_te)
print(f"[Hb regression] test: RMSE={mean_squared_error(yr_te, pred_te, squared=False):.1f} g/L  "
      f"R2={r2_score(yr_te, pred_te):.3f}  (n={len(yr_te)} pasien)")
print("(pembanding paper asli: RMSE ~20-24 g/L)")
""")

# ----------------------------------------------------------------------------
code("""\
# =============================================================================
# 11) Ringkasan + simpan metrik
# =============================================================================
summary = {
    "feature_based_cv_auc": cv_scores,
    "feature_based_best": best_f,
    "feature_based": {k: v for k, v in rows.items()},
    "cnn_threshold": th_cnn,
    "cnn": rows_cnn,
}
with open("/content/baseline_metrics.json", "w") as fh:
    json.dump(summary, fh, indent=2, default=str)
print(json.dumps(summary, indent=2, default=str))

print()
print("CATATAN:")
print("- Output = indikasi awal skrining, BUKAN diagnosis (disclaimer di produk akhir).")
print("- Sensitivitas (recall anemia) diprioritaskan: false positive -> periksa lab lebih baik")
print("  daripada anemia terlewat.")
""")

nb = {
    "cells": CELLS,
    "metadata": {
        "colab": {"provenance": [], "name": "baselines_colab.ipynb"},
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "version": "3.10"},
    },
    "nbformat": 4,
    "nbformat_minor": 0,
}
OUT.write_text(json.dumps(nb, indent=1), encoding="utf-8")
print("notebook ->", OUT, f"({len(CELLS)} sel)")