# -*- coding: utf-8 -*-
"""
02_preprocess.py — Bangun dataset akhir terdedup dari sumber mentah.

Keputusan (sesuai audit 01/01b/01c):
  - ayushcl DIKELUARKAN: 100% kontennya subset ghana (0 gambar unik).
  - udayranjan: hanya subset Nail_* dipakai (task ini = foto kuku). Eye_* off-scope.
  - Dedup global md5, prioritas: nature > ghana > udayranjan.
  - Label ghana dari prefix nama file (inventaris terverifikasi):
        anemic/anmeic  -> anemic
        non-anemic/non-anrmic -> non-anemic
  - Label udayranjan dari folder (Nail_Anemic/Nail_Non_Anemic).
  - nature: 3 crop kuku per pasien dari NAIL_BOUNDING_BOXES + label biner dari Hb
    (cutoff konservatif WHO 120 g/L utk S1 tanpa umur/sex — KONFIGURASI, gampang
    diubah; Hb asli tetap disimpan utk relabel). Konvensi bbox = [top,left,bottom,right]
    (Yakimov 2024), crop img[top:bottom, left:right] TANPA rotasi.
  - Keluaran: data/processed/images/*.jpg (224x224 RGB) + rows.csv.

Pakai: stdlib + pandas + Pillow. Idempoten (skip file yang sudah ada).
"""

import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd
from PIL import Image, ImageOps

RAW = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw")
PROC = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\processed")

TARGET = 224
HB_CUTOFF_GPERL = 120.0          # opsi (a) konservatif utk nature; ganti => relabel
QUALITY = 95

NATURE_META = RAW / "figshare-nature-photo-hb" / "metadata.csv"
NATURE_PHOTO = RAW / "figshare-nature-photo-hb" / "photo"
GHANA_DIR = RAW / "kaggle-ghana" / "Fingernails"
UDAY_DIR = RAW / "kaggle-udayranjan" / "Dataset_sample"

IMG_EXTS = {".png", ".jpg", ".jpeg", ".jfif", ".bmp"}

IMAGES_DIR = PROC / "images"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)


def md5_bytes(b: bytes) -> str:
    return hashlib.md5(b).hexdigest()


def load_image(path: Path) -> Image.Image:
    img = Image.open(path)
    img = ImageOps.exif_transpose(img)
    if img.mode != "RGB":
        img = img.convert("RGB")
    return img


def save_standard(img: Image.Image, out: Path) -> None:
    img = img.resize((TARGET, TARGET), Image.LANCZOS)
    img.save(out, "JPEG", quality=QUALITY)


def parse_ghana_name(name: str) -> tuple[str, str] | None:
    """-> (label, idpart) dari filename ghana/ayushcl. None kalau tidak cocok.

    Format: <label>-<id>[ (aug)] dengan label = anemic/anmeic/non-anemic/non-anrmic
    dan id = seri huruf+angka (+suffix huruf penanda jari, mis. FN-011FV).
    idpart DINORMALISASI: suffix huruf dibuang (FN-011FV & FN-011RA -> FN-011 =
    satu pasien yang sama) supaya foto jari-jari satu subjek tidak bocor antar split.
    """
    stem = name.rsplit(".", 1)[0].strip()
    stem = re.sub(r"\s*\(\d+\)\s*$", "", stem)
    stem = re.sub(r"\s+\d+(\s+\d+)*\s*$", "", stem)
    m = re.match(r"^(?P<label>[A-Za-z]+(?:-[A-Za-z]+)?)-(?P<id>[A-Za-z]+-\d+[A-Za-z]*)$", stem)
    if not m:
        return None
    raw_label = m.group("label").lower()
    idpart_full = m.group("id")
    if raw_label in ("anemic", "anmeic"):
        label = "anemic"
    elif raw_label in ("non-anemic", "non-anrmic"):
        label = "non-anemic"
    else:
        return None
    idpart = re.sub(r"[A-Za-z]+$", "", idpart_full)  # FN-011FV -> FN-011
    return label, idpart


def ghana_files() -> list[Path]:
    return sorted(p for p in GHANA_DIR.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXTS)


def uday_files() -> list[Path]:
    out = []
    for sub in ("Nail_Anemic", "Nail_Non_Anemic"):
        d = UDAY_DIR / sub
        if d.exists():
            out += [p for p in d.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXTS]
    return out


def main() -> None:
    rows: list[dict] = []
    seen_md5: set[str] = set()
    stats = defaultdict(Counter)
    skipped = Counter()

    # ---------- 1) NATURE (crop kuku + Hb) ----------
    df = pd.read_csv(NATURE_META)
    print(f"[nature] metadata: {len(df)} baris, {df['PATIENT_ID'].nunique()} pasien")
    for _, r in df.iterrows():
        pid = int(r["PATIENT_ID"])
        hb = float(r["HB_LEVEL_GperL"])
        photo = NATURE_PHOTO / f"{pid}.jpg"
        if not photo.exists():
            print(f"  ! foto tidak ada utk pasien {pid} — dilewati")
            continue
        try:
            boxes = json.loads(r["NAIL_BOUNDING_BOXES"])
            skin_boxes = json.loads(r["SKIN_BOUNDING_BOXES"])
        except Exception:  # noqa: BLE001
            print(f"  ! bbox gagal parse utk pasien {pid}")
            continue
        img = load_image(photo)
        for i, (box, sbox) in enumerate(zip(boxes, skin_boxes)):
            # Konvensi resmi (Yakimov et al. 2024, Sci Data 11:1070;
            # repo biophotonics-msu/photo-haemoglobin): tiap bbox adalah
            # [top, left, bottom, right] — BUKAN [x1, y1, x2, y2].
            # Crop resmi: img[top:bottom, left:right] (tanpa rotasi).
            top, left, bottom, right = (int(v) for v in box)
            if right <= left or bottom <= top:
                continue
            crop = img.crop((left, top, right, bottom))
            pid_safe = re.sub(r"[^A-Za-z0-9_\-]", "_", str(pid))
            image_id = f"nature_{pid_safe}_{i}.jpg"
            out_path = IMAGES_DIR / image_id
            save_standard(crop, out_path)
            lab = "anemic" if hb < HB_CUTOFF_GPERL else "non-anemic"
            rows.append({
                "image_id": image_id, "source": "nature", "patient_id": pid,
                "label": lab, "hb_g_dl": round(hb / 10.0, 1),
                "nail_bbox": json.dumps(box), "skin_bbox": json.dumps(sbox),
                "in_path": str(photo), "md5": md5_bytes(out_path.read_bytes()),
                "out_path": str(out_path),
            })
            stats["nature"][lab] += 1
        img.close()
    print(f"  nature: {stats['nature']['anemic']} anemic / "
          f"{stats['nature']['non-anemic']} non-anemic (cutoff {HB_CUTOFF_GPERL} g/L)")

    # ---------- 2) GHANA ----------
    n_new = 0
    unparsed_names = []
    for p in ghana_files():
        parsed = parse_ghana_name(p.name)
        if parsed is None:
            unparsed_names.append(p.name)
            skipped["ghana_unparsed"] += 1
            continue
        label, idpart = parsed
        if idpart != re.sub(r"[A-Za-z]+$", "", idpart):
            print(f"  ! idpart tidak ternormalisasi: {idpart!r}")
        content = p.read_bytes()
        h = md5_bytes(content)
        if h in seen_md5:
            skipped["ghana_dup_md5"] += 1
            continue
        seen_md5.add(h)
        img = load_image(p)
        pid_safe = re.sub(r"[^A-Za-z0-9_\-]", "_", f"{label}_{idpart}")
        image_id = f"ghana_{pid_safe}_{n_new}.jpg"
        out_path = IMAGES_DIR / image_id
        save_standard(img, out_path)
        img.close()
        rows.append({
            "image_id": image_id, "source": "ghana", "patient_id": f"{label}_{idpart}",
            "label": label, "hb_g_dl": None,
            "nail_bbox": None, "skin_bbox": None,
            "in_path": str(p), "md5": h, "out_path": str(out_path),
        })
        stats["ghana"][label] += 1
        n_new += 1
    if unparsed_names:
        print(f"  !!! {len(unparsed_names)} file ghana TIDAK TERPARSE:")
        for n in unparsed_names[:20]:
            print(f"      {n}")
    print(f"  ghana: {stats['ghana']['anemic']} anemic / "
          f"{stats['ghana']['non-anemic']} non-anemic (skipped {skipped['ghana_dup_md5']})")

    # ---------- 3) UDAYRANJAN (nail saja) ----------
    n_new = 0
    for p in uday_files():
        label = "anemic" if "Nail_Anemic" in p.parts else "non-anemic"
        content = p.read_bytes()
        h = md5_bytes(content)
        if h in seen_md5:
            skipped["uday_dup_md5"] += 1
            continue
        seen_md5.add(h)
        cleaned = re.sub(r"\s*\(\d+\)\s*$", "", p.stem).strip()
        if re.search(r"\d", cleaned):
            pid = f"{label}_{cleaned}"        # ada ID asli -> kelompokkan augmentasi
        else:
            pid = f"{label}_{p.stem}"         # tanpa ID -> tiap file = pasien unik
        pid_safe = re.sub(r"[^A-Za-z0-9_\-]", "_", pid)
        img = load_image(p)
        image_id = f"uday_{pid_safe}_{n_new}.jpg"
        out_path = IMAGES_DIR / image_id
        save_standard(img, out_path)
        img.close()
        rows.append({
            "image_id": image_id, "source": "udayranjan", "patient_id": pid,
            "label": label, "hb_g_dl": None,
            "nail_bbox": None, "skin_bbox": None,
            "in_path": str(p), "md5": h, "out_path": str(out_path),
        })
        stats["udayranjan"][label] += 1
        n_new += 1
    print(f"  udayranjan: {stats['udayranjan']['anemic']} anemic / "
          f"{stats['udayranjan']['non-anemic']} non-anemic "
          f"(skipped {skipped['uday_dup_md5']})")

    # ---------- simpan ----------
    df_out = pd.DataFrame(rows)
    df_out.to_csv(PROC / "rows.csv", index=False)
    print(f"\nTOTAL unik: {len(df_out)} gambar | label {dict(df_out['label'].value_counts())}")
    print(f"pasien unik: {df_out['patient_id'].nunique()}")
    print(f"skipped: {dict(skipped)}")
    print(f"rows.csv -> {PROC / 'rows.csv'}")


if __name__ == "__main__":
    main()