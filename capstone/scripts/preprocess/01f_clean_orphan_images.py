# -*- coding: utf-8 -*-
"""Hapus file gambar yatim di data/processed/images (tidak direferensikan CSV)."""
from pathlib import Path
import pandas as pd

img = Path(r"data/processed/images")
used = set(pd.read_csv(r"data/processed/dataset.csv")["image_id"])
removed = [p.unlink() for p in img.glob("*.jpg") if p.name not in used]
print(f"removed orphans: {len(removed)}")
print(f"images dir sekarang: {len(list(img.glob('*.jpg')))} file")