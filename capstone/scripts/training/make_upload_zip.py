# -*- coding: utf-8 -*-
"""
make_upload_zip.py — Bungkus data training ke data/upload/anemia_nail_dataset_v1.zip
(siap di-upload ke Google Drive / Colab).

Isi zip:
  anemia_nail_dataset_v1/
    README.md          <- ringkasan + kolom CSV
    dataset.csv        <- 2.907 baris (master, ada kolom split)
    train.csv / val.csv / test.csv   <- split per-pasien (dipakai notebook)
    images/            <- 2.907 jpg 224x224 (image_id = nama file)
"""

import hashlib
import zipfile
from pathlib import Path

PROC = Path(r"data/processed")
OUT_DIR = Path(r"data/upload")
OUT_DIR.mkdir(parents=True, exist_ok=True)
ZIP_PATH = OUT_DIR / "anemia_nail_dataset_v1.zip"

README = """# anemia_nail_dataset_v1 — Skrining anemia dari foto kuku (Capstone Sem 5)

## Isi
- images/            2.907 jpg 224x224 (nama file = image_id di CSV)
- dataset.csv        master: semua gambar + kolom split
- train.csv / val.csv / test.csv   split PER-PASIEN (WAJIB dipakai apa adanya)
- source: ghana (2.097) | nature (750, crop kuku dari bbox) | udayranjan (60)

## Kolom CSV
- image_id     nama file di images/
- source       ghana | nature | udayranjan
- patient_id   id pasien (satu pasien TIDAK boleh lintas split)
- label        anemic | non-anemic (cut-off WHO 2024 utk nature: Hb < 120 g/L)
- hb_g_dl      Hb asli (g/dL) — hanya nature; lainnya kosong
- split        train | val | test (70/15/15 per pasien, seed 42)

## Catatan
- in_path/out_path/md5/bounding boxes = artefak lokal Windows, abaikan di Colab.
- Model output = INDIKASI AWAL skrining, BUKAN diagnosis.
- Notebook pelatihan: scripts/training/baselines_colab.ipynb (repo lokal).
"""


def main() -> None:
    images = sorted((PROC / "images").glob("*.jpg"))
    assert len(images) == 2907, f"jumlah gambar harus 2907, sekarang {len(images)}"
    for csv_name in ("dataset.csv", "train.csv", "val.csv", "test.csv"):
        assert (PROC / csv_name).exists(), f"butuh {csv_name}"

    with zipfile.ZipFile(ZIP_PATH, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.writestr("anemia_nail_dataset_v1/README.md", README)
        for csv_name in ("dataset.csv", "train.csv", "val.csv", "test.csv"):
            z.write(PROC / csv_name, f"anemia_nail_dataset_v1/{csv_name}")
        for img in images:
            z.write(img, f"anemia_nail_dataset_v1/images/{img.name}")

    h = hashlib.md5(ZIP_PATH.read_bytes()).hexdigest()
    print(f"zip -> {ZIP_PATH}")
    print(f"size: {ZIP_PATH.stat().st_size / 1e6:.1f} MB | md5: {h}")


if __name__ == "__main__":
    main()