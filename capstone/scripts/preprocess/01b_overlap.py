# -*- coding: utf-8 -*-
"""
01b_overlap.py — Analisis overlap & konflik label antar sumber (untuk desain dedup).

Menjawab:
  1. Matriks overlap md5 berpasangan.
  2. Kalau dedup global dengan prioritas [nature > ghana > ayushcl > udayranjan]:
     berapa file unik per sumber, berapa yang terbuang (redundan).
  3. Konflik label: adakah md5 yang sama tapi label berbeda antar sumber?
  4. Contoh nama file untuk varian label aneh (anemic-n, non, anmeic, non-anrmic).
"""

import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

RAW = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw")
IMG_EXTS = {".png", ".jpg", ".jpeg", ".jfif", ".bmp"}

SOURCES = {
    "nature": RAW / "figshare-nature-photo-hb" / "photo",
    "ghana": RAW / "kaggle-ghana" / "Fingernails",
    "ayushcl": RAW / "kaggle-ayushcl" / "Finger_Nails",
    "udayranjan": RAW / "kaggle-udayranjan" / "Dataset_sample",
}
PRIORITY = ["nature", "ghana", "ayushcl", "udayranjan"]


def md5_file(p: Path) -> str:
    h = hashlib.md5()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def label_from(nm: str) -> str:
    """Label biner buat file ghana/ayushcl/udayranjan (dari nama file, lowercase)."""
    n = nm.lower().replace("_", "-")
    if n.startswith(("non-anemic", "non-anrmic", "non")) or "/non/" in n:
        return "non-anemic"
    return "anemic"


def main() -> None:
    # (source) -> list of (path, md5, label)
    entries: dict[str, list[tuple[Path, str, str]]] = {}
    md5_seen: dict[str, list[tuple[str, str]]] = defaultdict(list)  # md5 -> [(src,label)]

    for name in PRIORITY:
        root = SOURCES[name]
        files = (
            [p for p in root.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXTS]
            if name in ("nature", "ghana")
            else [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in IMG_EXTS]
        )
        lst = []
        for p in files:
            if name == "nature":
                lab = "hb-based"
            else:
                # udayranjan: label dari folder (ground truth); lainnya dari nama file
                lab = ("anemic" if "anemic" in str(p).lower() and "non" not in str(p).lower()
                       else "non-anemic") if name == "udayranjan" else label_from(p.name)
            h = md5_file(p)
            md5_seen[h].append((name, lab))
            lst.append((p, h, lab))
        entries[name] = lst
        print(f"[{name}] {len(lst)} file index")

    # 1) matriks overlap
    print("\n== 1) MATRIKS OVERLAP (jumlah md5 yang dipakai kedua sumber) ==")
    srcs = PRIORITY
    m = {s: {t: 0 for t in srcs} for s in srcs}
    for h, es in md5_seen.items():
        ss = {e[0] for e in es}
        for a in ss:
            for b in ss:
                if a != b:
                    m[a][b] += 1
    hdr = "".join(f"{s:>12}" for s in srcs)
    print(f"{'':>12}{hdr}")
    for a in srcs:
        print(f"{a:>12}" + "".join(f"{m[a][b]:>12}" for b in srcs))

    # 2) dedup global prioritas
    print("\n== 2) DEDUP GLOBAL (prioritas nature>ghana>ayushcl>udayranjan) ==")
    kept: dict[str, int] = {s: 0 for s in srcs}
    dup_into: dict[str, int] = {s: 0 for s in srcs}
    seen = set()
    for s in srcs:
        for p, h, lab in entries[s]:
            if h in seen:
                dup_into[s] += 1
            else:
                seen.add(h)
                kept[s] += 1
    tot = sum(len(v) for v in entries.values())
    print(f"total file semua sumber: {tot}")
    print(f"unik konten global        : {len(seen)}  ({len(seen)/tot*100:.0f}% dari total)")
    for s in srcs:
        print(f"  {s:>10}: kept={kept[s]:>5}  redundant={dup_into[s]:>5}  "
              f"(raw={len(entries[s])})")

    # 3) konflik label
    print("\n== 3) KONFLIK LABEL (md5 sama, label beda antar sumber) ==")
    conflicts = 0
    for h, es in md5_seen.items():
        labs = {e[1] for e in es}
        if len(labs) > 1 and "hb-based" not in labs:
            conflicts += 1
            if conflicts <= 6:
                print(f"  {h[:10]}… -> {es}")
        elif len(labs) > 1 and "hb-based" in labs:
            conflicts += 1
            if conflicts <= 6:
                print(f"  {h[:10]}… (vs Nature/Hb) -> {es}")
    if conflicts == 0:
        print("  tidak ada konflik")
    else:
        print(f"  total md5 konflik: {conflicts}")

    # 4) contoh nama file varian aneh
    print("\n== 4) CONTOH NAMA FILE VARIAN ==")
    def show(s, pat, k=6):
        hits = [p.name for p, _, _ in entries[s] if re.search(pat, p.name)][:k]
        print(f"  {s} / {pat}: {hits}")
    show("ghana", r"[Aa]nmeic", 4)
    show("ghana", r"[Nn]on-?[Aa]nrmic", 4)
    show("udayranjan", r"^Anemic-N", 6)
    show("udayranjan", r"^Non ", 6)
    show("ayushcl", r"[Nn]on-?[Aa]nrmic", 3)

    # simpan ringkasan
    out = {
        "overlap_matrix": m,
        "kept_after_dedup": kept,
        "redundant": dup_into,
        "n_unique_global": len(seen),
        "n_label_conflicts": conflicts,
    }
    (RAW.parent / "processed" / "overlap_summary.json").write_text(
        json.dumps(out, indent=2), encoding="utf-8")
    print("\nRingkasan tersimpan: data/processed/overlap_summary.json")


if __name__ == "__main__":
    main()