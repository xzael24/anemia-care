# -*- coding: utf-8 -*-
"""
03_splits.py — Split per-pasien (anti bocor antar augmentasi), stratified 70/15/15.

  - Kelompokkan semua gambar per patient_id (foto/augmentasi pasien yang sama
    TIDAK BOLEH terpisah antar train/val/test).
  - Rasio label harus mirip di tiap split (stratify per label pasien).
  - Keluaran:
      data/processed/dataset.csv     (semua baris + kolom split)
      data/processed/train.csv|val.csv|test.csv
      data/processed/split_report.json
      data/processed/{train,val,test}/images/  (salinan file, siap training)
"""

import json
import random
import shutil
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

PROC = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\processed")
SEED = 42
TRAIN, VAL, TEST = 0.70, 0.15, 0.15

rng = random.Random(SEED)


def split_labeled(patient_labels: dict[str, str]) -> dict[str, str]:
    """Stratified patient-level split. patient_labels: patient_id -> label."""
    by_label: dict[str, list[str]] = defaultdict(list)
    for pid, lab in patient_labels.items():
        by_label[lab].append(pid)

    assign: dict[str, str] = {}
    for lab, pids in by_label.items():
        rng.shuffle(pids)
        n = len(pids)
        n_tr = round(n * TRAIN)
        n_va = round(n * VAL)
        for i, pid in enumerate(pids):
            if i < n_tr:
                assign[pid] = "train"
            elif i < n_tr + n_va:
                assign[pid] = "val"
            else:
                assign[pid] = "test"
    return assign


def main() -> None:
    df = pd.read_csv(PROC / "rows.csv")
    df["label"] = df["label"].astype(str)

    # 1) validasi: label seragam dalam satu pasien
    lab_by_patient = df.groupby("patient_id")["label"].unique()
    multi = {p: list(l) for p, l in lab_by_patient.items() if len(l) > 1}
    if multi:
        print("!!! PASANGAN PASIEN DENGAN LABEL CAMPURAN:")
        for p, l in list(multi.items())[:10]:
            print(f"    {p}: {l}")
        raise SystemExit("Hentikan: ada pasien berlabel campur — periksa pemetaan label.")

    patient_labels = {p: l[0] for p, l in lab_by_patient.items()}
    assign = split_labeled(patient_labels)

    df["split"] = df["patient_id"].map(assign)
    for sp in ("train", "val", "test"):
        if sp not in df["split"].unique():
            print(f"!!! split {sp} kosong — periksa rasio/stratifikasi")
            raise SystemExit(1)

    # 2) salin gambar ke folder split
    for sp in ("train", "val", "test"):
        out = PROC / sp / "images"
        out.mkdir(parents=True, exist_ok=True)
    for _, r in df.iterrows():
        dst = PROC / r["split"] / "images" / r["image_id"]
        if not dst.exists():
            shutil.copy2(r["out_path"], dst)

    # 3) tulis CSV
    df.to_csv(PROC / "dataset.csv", index=False)
    for sp in ("train", "val", "test"):
        df[df["split"] == sp].to_csv(PROC / f"{sp}.csv", index=False)

    # 4) laporan
    report = {
        "seed": SEED,
        "ratio": {"train": TRAIN, "val": VAL, "test": TEST},
        "n_patients": len(patient_labels),
        "n_images_total": len(df),
        "by_source": {
            s: {"images": int(n), "patients": df[df["source"] == s]["patient_id"].nunique()}
            for s, n in df["source"].value_counts().items()
        },
        "splits": {},
        "label_balance_per_split": {},
    }
    for sp in ("train", "val", "test"):
        sub = df[df["split"] == sp]
        report["splits"][sp] = {
            "images": int(len(sub)),
            "patients": int(sub["patient_id"].nunique()),
        }
        report["label_balance_per_split"][sp] = {
            k: int(v) for k, v in sub["label"].value_counts().items()
        }
    (PROC / "split_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    # 5) ringkasan
    print("=" * 60)
    print("SPLIT PER PASIEN (stratified, seed 42)")
    print("=" * 60)
    for sp in ("train", "val", "test"):
        sub = df[df["split"] == sp]
        bal = report["label_balance_per_split"][sp]
        pct = 100 * len(sub) / len(df)
        print(f"[{sp:>5}] gambar={len(sub):>4} ({pct:4.1f}%)  pasien={sub['patient_id'].nunique():>3}  "
              f"label={bal}")
    print("\nPer sumber:")
    for s, v in report["by_source"].items():
        print(f"  {s:>10}: {v['images']} gambar / {v['patients']} pasien")
    print(f"\nTotal: {report['n_images_total']} gambar, {report['n_patients']} pasien")
    print("CSV -> dataset.csv, train.csv, val.csv, test.csv | laporan -> split_report.json")


if __name__ == "__main__":
    main()