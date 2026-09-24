# -*- coding: utf-8 -*-
"""
01e_verify_nature_crops.py — Verifikasi akhir fix crop nature (bbox [top,left,bottom,right]).

1) Cek otomatis: semua crop nature non-degenerate (std warna cukup -> tidak ter-clip abu-abu).
2) Buat bukti visual (2 pasien): foto annotated + strip crop, ke data/evidence_nature_crop_fix/.
3) Hapus folder diagnostik lama data/tmp_rotate_test/.
"""

import json
import shutil
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw, ImageFont

BASE = Path(r"data/raw/figshare-nature-photo-hb")
DF = pd.read_csv(BASE / "metadata.csv")
IMG_DIR = Path(r"data/processed/images")
OUT_DIR = Path(r"data/evidence_nature_crop_fix")


def main() -> None:
    # ---------- 1) cek otomatis semua crop nature ----------
    crops = sorted(IMG_DIR.glob("nature_*.jpg"))
    bad = []
    for p in crops:
        a = np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)
        std = float(a.std(axis=(0, 1)).mean())
        mean = float(a.mean(axis=(0, 1)).mean())
        if std < 8.0:  # crop ter-clip ke area kosong => hampir rata
            bad.append((p.name, round(std, 2), round(mean, 2)))
    print(f"[check] total crop nature: {len(crops)} | degenerate: {len(bad)}")
    for b in bad[:15]:
        print("   DEGENERATE:", b)
    if not bad:
        print("  => SEMUA crop nature valid (std >= 8)")

    # ---------- 2) bukti visual ----------
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True)
    font = ImageFont.load_default()
    for pid in (1, 100):
        r = DF[DF["PATIENT_ID"] == pid].iloc[0]
        img = Image.open(BASE / "photo" / f"{pid}.jpg").convert("RGB")
        nails = json.loads(r["NAIL_BOUNDING_BOXES"])
        skins = json.loads(r["SKIN_BOUNDING_BOXES"])
        d = ImageDraw.Draw(img)
        for b in nails:
            t, l, bo, ri = (int(v) for v in b)
            d.rectangle([l, t, ri, bo], outline=(255, 0, 0), width=3)
        for b in skins:
            t, l, bo, ri = (int(v) for v in b)
            d.rectangle([l, t, ri, bo], outline=(0, 100, 255), width=3)
        d.rectangle([350, 300, 400, 350], outline=(0, 200, 0), width=3)  # white ref
        d.text((8, 8), f'pid={pid} Hb={r["HB_LEVEL_GperL"]:.0f} g/L', fill=(0, 0, 0), font=font)
        img.save(OUT_DIR / f"pid{pid}_annotated.jpg", "JPEG", quality=90)

        imgs = [img]
        for b in nails:
            t, l, bo, ri = (int(v) for v in b)
            imgs.append(img.crop((l, t, ri, bo)).resize((224, 224)))
        sheet = Image.new("RGB", (224 * len(imgs), 224), (255, 255, 255))
        for i, im in enumerate(imgs):
            sheet.paste(im, (i * 224, 0))
        sheet.save(OUT_DIR / f"pid{pid}_crops_strip.jpg", "JPEG", quality=90)
    print("evidence ->", OUT_DIR)

    # ---------- 3) bersihkan diagnostik lama ----------
    tmp = Path(r"data/tmp_rotate_test")
    if tmp.exists():
        shutil.rmtree(tmp)
        print("tmp_rotate_test dihapus")


if __name__ == "__main__":
    main()