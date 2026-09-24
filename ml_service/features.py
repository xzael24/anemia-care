"""Ekstraksi fitur 33D — REPLIKA PERSIS baseline (scripts/training/build_notebook.py cell 4).

Catatan penting: logika ini harus identik dengan notebook biar prediksi serving
nyambung dengan metrik evaluasi baseline (test RF: AUC 0.846).
"""
import numpy as np
import cv2

PCTS = [5, 15, 25, 50, 75, 85, 95]


def extract_features(rgb: np.ndarray) -> np.ndarray:
    """33 fitur: persentil RGB (21) + rasio R/(G+B) (3) + LAB (5) + HSV (2) + gray (2).

    rgb: array uint8 shape (H, W, 3) dalam RGB.
    """
    f = np.float32(rgb) + 1.0
    R, G, B = f[..., 0], f[..., 1], f[..., 2]
    feats: list[float] = []
    for ch in range(3):
        feats.extend(np.percentile(rgb[..., ch], PCTS))                # 21
    feats.extend([np.mean(R / (G + B)), np.mean(G / (R + B)),
                  np.mean(B / (R + G))])                               # 3
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    feats.extend([lab[..., 0].mean(), lab[..., 1].mean(), lab[..., 2].mean(),
                  lab[..., 1].std(), lab[..., 2].std()])               # 5
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    feats.extend([hsv[..., 1].mean(), hsv[..., 2].mean()])             # 2
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    feats.extend([gray.mean(), gray.std()])                            # 2
    return np.array(feats, dtype=np.float32)                           # total 33