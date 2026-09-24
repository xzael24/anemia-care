# -*- coding: utf-8 -*-
"""
01_audit.py — Audit & inventory semua sumber dataset sebelum preprocessing.

Tugas:
  1. Hitung file per sumber, zero-byte, ekstensi.
  2. MD5 per file -> deteksi duplikat konten (dalam sumber & antar sumber = risiko data leak).
  3. Inventaris label asli dari nama file (Ghana, ayushcl) — MENGHADIRKAN semua varian
     (typo "Anmeic/Anrmic" dll) supaya parser label di 02 akurat, bukan ditebak.
  4. Audit metadata Nature (metadata.csv): jumlah pasien, parse bbox, anomali foto.
  5. Tulis data/processed/audit_report.json + ringkasan ke stdout.

Pakai: stdlib + pandas (buat metadata Nature). Tidak mengubah file apa pun.
"""

import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

RAW = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw")
OUT = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\processed")
OUT.mkdir(parents=True, exist_ok=True)

SOURCES = {
    "nature": RAW / "figshare-nature-photo-hb",
    "ghana": RAW / "kaggle-ghana" / "Fingernails",
    "ayushcl": RAW / "kaggle-ayushcl" / "Finger_Nails",
    "udayranjan": RAW / "kaggle-udayranjan" / "Dataset_sample",
}

IMG_EXTS = {".png", ".jpg", ".jpeg", ".jfif", ".bmp"}


def md5_file(p: Path) -> str:
    h = hashlib.md5()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def gather(images_dir: Path, subfolder: bool) -> list[Path]:
    """Kumpulkan semua file gambar di images_dir (atau subfolder-nya)."""
    if subfolder:
        return [
            p for p in images_dir.rglob("*")
            if p.is_file() and p.suffix.lower() in IMG_EXTS
        ]
    return [p for p in images_dir.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXTS]


def label_prefix(name: str) -> str:
    """Ekstrak token label (prefix) dari nama file bertipe 'Anemic-Fin-007 (10).png'.

    Aturan: buang suffix '(N)' / ' N' / ' N M', lalu ambil token sebelum token
    yang mengandung angka & huruf campur (mis. 'Fin-007', 'FN-143', 'fn-0001').
    """
    stem = name.rsplit(".", 1)[0]
    stem = re.sub(r"\s*\(\d+\)\s*$", "", stem)
    stem = re.sub(r"\s+\d+(\s+\d+)*\s*$", "", stem)
    parts = stem.split("-")
    label = []
    for part in parts:
        if re.search(r"\d", part):  # token id seperti 'Fin' tidak ada angka,
            break                    # token 'Fin' tanpa angka masih label? cek di bawah
        label.append(part)
    if not label:
        # kasus 'Non-anemic (1)' -> parts = ['Non', 'anemic (1)'] -> label keluar
        # lebih dulu. Fallback: ambil part pertama.
        label = [parts[0]]
    return "-".join(label).lower()


def main() -> None:
    report: dict = {"sources": {}, "overlaps": {}, "nature": {}}

    per_source_files: dict[str, list[Path]] = {}
    md5_index: dict[str, list[str]] = defaultdict(list)  # md5 -> [(source, relpath)]

    for name, root in SOURCES.items():
        if not root.exists():
            report["sources"][name] = {"error": "DIR TIDAK ADA"}
            continue

        # Struktur: nature/photo flat; ghana flat; ayushcl & udayranjan pakai subfolder
        if name == "nature":
            files = gather(root / "photo", subfolder=False)
        elif name in ("ghana",):
            files = gather(root, subfolder=False)
        else:
            files = gather(root, subfolder=True)

        n_zero = 0
        ext_counter: Counter = Counter()
        label_counter: Counter = Counter()
        baseid_counter: Counter = Counter()
        info: list[dict] = []

        for p in files:
            size = p.stat().st_size
            ext_counter[p.suffix.lower()] += 1
            if size == 0:
                n_zero += 1
            d = {"name": p.name, "size": size, "rel": str(p.relative_to(root))}
            if name in ("ghana", "ayushcl", "udayranjan"):
                d["label_prefix"] = label_prefix(p.name)
                label_counter[d["label_prefix"]] += 1
                # base id = nama file tanpa suffix augmentasi, tanpa ekstensi
                baseid_counter[p.name.rpartition(".")[0].split(" (")[0]] += 1
            h = md5_file(p)
            d["md5"] = h
            md5_index[h].append((name, d["rel"]))
            info.append(d)

        per_source_files[name] = files
        report["sources"][name] = {
            "n_files": len(files),
            "n_zero_byte": n_zero,
            "extensions": dict(ext_counter),
            "labels": dict(label_counter),
            "n_base_ids": len(baseid_counter),
            "size_bytes": sum(f.stat().st_size for f in files),
        }

        # duplikat konten di dalam sumber
        dup_inside = {h: n for h, n in Counter(i["md5"] for i in info).items() if n > 1}
        report["sources"][name]["dup_content_inside"] = dup_inside

    # overlap konten antar sumber (data leak check)
    overlap_md5: dict[str, list[str]] = defaultdict(list)
    for h, entries in md5_index.items():
        srcs = sorted({e[0] for e in entries})
        if len(srcs) > 1:
            overlap_md5[h] = srcs
    report["overlaps"]["by_md5"] = {
        h: v for h, v in sorted(overlap_md5.items(), key=lambda x: -len(x[1]))
    }
    report["overlaps"]["n_md5_shared"] = len(overlap_md5)

    # == Nature metadata ==
    meta_path = SOURCES["nature"] / "metadata.csv"
    if meta_path.exists():
        df = pd.read_csv(meta_path)
        n_patients = df["PATIENT_ID"].nunique()
        n_rows = len(df)
        # cek parse bbox
        bbox_ok = truth = 0
        bbox_fail = []
        for pid, raw in zip(df["PATIENT_ID"], df["NAIL_BOUNDING_BOXES"]):
            try:
                boxes = json.loads(raw)
                if isinstance(boxes, list) and len(boxes) == 3:
                    truth += 1
                else:
                    bbox_fail.append((pid, "len != 3"))
            except Exception as e:  # noqa: BLE001
                bbox_fail.append((pid, str(e)))
        photos = gather(SOURCES["nature"] / "photo", subfolder=False)
        photo_ids = {p.stem for p in photos}
        meta_ids = set(df["PATIENT_ID"].astype(str))
        report["nature"] = {
            "n_rows_metadata": n_rows,
            "n_patients": n_patients,
            "n_photos": len(photos),
            "bbox_parse_ok": truth,
            "bbox_fail": bbox_fail[:20],
            "photo_without_metadata": sorted(photo_ids - meta_ids),
            "metadata_without_photo": sorted(meta_ids - photo_ids)[:20],
            "hb_min_gperl": float(df["HB_LEVEL_GperL"].min()),
            "hb_max_gperl": float(df["HB_LEVEL_GperL"].max()),
            "hb_median_gperl": float(df["HB_LEVEL_GperL"].median()),
        }

    with (OUT / "audit_report.json").open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    # == Ringkasan stdout ==
    print("=" * 70)
    print("AUDIT DATASET — ringkasan")
    print("=" * 70)
    for name, s in report["sources"].items():
        if "error" in s:
            print(f"[{name}] {s['error']}")
            continue
        print(f"\n[{name}] files={s['n_files']}  zero={s['n_zero_byte']}  "
              f"size={s['size_bytes']/1e6:.1f} MB  base_ids={s['n_base_ids']}")
        print(f"    ekstensi: {s['extensions']}")
        if s.get("labels"):
            print("    LABEL PREFIX (inventory asli):")
            for k, v in sorted(s["labels"].items()):
                print(f"        {k!r:28} {v}")
        if s.get("dup_content_inside"):
            print(f"    duplikat konten di dalam: {len(s['dup_content_inside'])} md5 (lihat json)")
    print("\n[overlap antar sumber] md5 yang dipakai 2+ sumber:", report["overlaps"]["n_md5_shared"])
    for h, srcs in list(report["overlaps"]["by_md5"].items())[:8]:
        print(f"    {h[:10]}… -> {srcs}")
    n = report["nature"]
    print("\n[nature] ", json.dumps({k: v for k, v in n.items() if k != "bbox_fail"}, indent=4))
    if n.get("bbox_fail"):
        print("    bbox fail:", n["bbox_fail"][:5])
    print("\nLaporan lengkap: data/processed/audit_report.json")


if __name__ == "__main__":
    main()