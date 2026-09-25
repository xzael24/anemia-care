"""Kalibrasi threshold deteksi keburaman (Laplacian Variance) pada data riil.

Ide: foto figshare (tajam, dari kamera dataset) jadi populasi "tajam";
versi yang di-Gaussian-blur (sigma 2 dan 4) jadi populasi "buram".
Threshold dipilih supaya foto tajam hampir tak pernah tertolak (false
reject ~0) sambil tetap menangkap buram wajar (sigma>=4).

Skala dinormalisasi: sisi terpanjang -> 480px (LV sensitif resolusi,
jadi harus dinormalisasi dulu sebelum dibandingkan lintas HP).

Menulis qc_blur_results.csv + print ringkasan (console ASCII, cp1252).
"""
import csv
from pathlib import Path

import cv2
import numpy as np

FOTO = Path(
    r"C:\Users\AcerAG14\Documents\Kuliah\Semester 5 Percaya\CAPSTONE"
    r"\data\raw\figshare-nature-photo-hb\photo"
)
OUT = Path(r"C:\Users\AcerAG14\AppData\Local\Temp\opencode\qc_blur_results.csv")
ANALISIS = 480  # panjang sisi terpanjang setelah resize


def varian_laplacian(bgr):
    """LV pada skala analisis tetap (anti sensitivitas resolusi)."""
    h, w = bgr.shape[:2]
    skala = ANALISIS / max(h, w)
    if skala < 1:
        bgr = cv2.resize(bgr, (int(w * skala), int(h * skala)))
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


foto = sorted(FOTO.glob("*.jpg"))
print("foto:", len(foto))

rows = []
sharp = []
for p in foto:
    img = cv2.imread(str(p))
    lv = varian_laplacian(img)
    sharp.append(lv)
    for sigma in (2, 4, 6):
        ble = cv2.GaussianBlur(img, (0, 0), sigma)
        lv_b = varian_laplacian(ble)
        rows.append(
            {
                "file": p.name,
                "jenis": "sharp" if sigma == 0 else f"blur_s{sigma}",
                "lv": round(lv_b if sigma else lv, 1),
            }
        )

with open(OUT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["file", "jenis", "lv"])
    w.writeheader()
    w.writerows(rows)

sharp = np.array(sharp)
print("SHARP figshare (n=%d): min %.0f | p1 %.0f | p5 %.0f | median %.0f"
      % (len(sharp), sharp.min(), np.percentile(sharp, 1),
         np.percentile(sharp, 5), np.median(sharp)))
for sigma in (2, 4, 6):
    vb = np.array([r["lv"] for r in rows if r["jenis"] == f"blur_s{sigma}"])
    print("BLUR s%d          : max %.0f | p95 %.0f | median %.0f"
          % (sigma, vb.max(), np.percentile(vb, 95), np.median(vb)))