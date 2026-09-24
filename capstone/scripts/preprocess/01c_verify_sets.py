# -*- coding: utf-8 -*-
"""Verifikasi ground truth set overlap antar sumber (md5 level)."""
import hashlib
from pathlib import Path

RAW = Path(r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE\data\raw")
IMG = {".png", ".jpg", ".jpeg"}


def md5_map(root: Path, recursive: bool) -> dict[Path, str]:
    if recursive:
        ps = [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in IMG]
    else:
        ps = [p for p in root.iterdir() if p.is_file() and p.suffix.lower() in IMG]
    return {p: hashlib.md5(p.read_bytes()).hexdigest() for p in ps}


ghana = md5_map(RAW / "kaggle-ghana" / "Fingernails", False)
ayush = md5_map(RAW / "kaggle-ayushcl" / "Finger_Nails", True)
uday = md5_map(RAW / "kaggle-udayranjan" / "Dataset_sample", True)

sg, sa, su = set(ghana.values()), set(ayush.values()), set(uday.values())
print(f"distinct md5 -> ghana={len(sg)}  ayushcl={len(sa)}  uday={len(su)}")
print(f"ayush & ghana            = {len(sa & sg)}")
print(f"ayush & uday             = {len(sa & su)}")
print(f"ayush - (ghana|uday)    = {len(sa - sg - su)}  <-- unik ayushcl")
print(f"ayush - ghana            = {len(sa - sg)}  <-- kalau 0, ayushcl full subset ghana")
print(f"ghana - ayush            = {len(sg - sa)}")
print(f"uday - ghana             = {len(su - sg)}")
print(f"ghana & uday             = {len(sg & su)}")

# contoh file ayushcl yang unik (kalau ada)
uniq_ayush = [p for p, h in ayush.items() if h not in sg and h not in su]
print("\ncontoh ayushcl unik:", [p.name for p in uniq_ayush[:8]])
print("jumlah file ayushcl unik:", len(uniq_ayush))