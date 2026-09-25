"""Anemia Care - ML Sidecar (FastAPI).

Kontrak (dipakai backend NestJS -> ml.service.ts):
  POST /predict   multipart field "file" (foto kuku)
    200 -> {"label": "anemia"|"normal", "probability": 0-1,
            "hb_estimate_gdl": null, "model": "rf_v1"}

Preprocessing serving (harus nyambung training):
  resize 224x224 (LANCZOS) -> RGB -> fitur 33D -> RandomForest proba.

Catatan: v1 ini belum ada segmentasi kuku / normalisasi pencahayaan lanjutan
(mirip gambar ghana/udayranjan yang emang close-up kuku). Segmen&bbox jadi
iterasi PCD berikutnya.

WAJIB: input = foto kuku close-up (kuku mengisi frame). Foto tangan penuh /
foto ilmiah (kartu kalibrasi, lighting beda) = di luar domain model — hasil
probabilitas tidak bermakna (lihat ml_service/README.md "Temuan evaluasi").
"""
from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path

import cv2
import joblib
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image
from pydantic import BaseModel, Field

from features import extract_features

HERE = Path(__file__).resolve().parent
MODEL_PATH = HERE / "rf_model.joblib"
# Threshold recall-aware (eksperimen eval_threshold.py): dipilih VALIDATION agar
# recall anemia >= 0.85 (sens 0.877 / spec 0.614 / prec 0.649 di TEST).
# Trade-off disengaja: skrining awal lebih baik "false positive" daripada
# meloloskan anemia (KONSEP: prioritas sensitivitas; output tetap indikasi
# awal + disclaimer, bukan diagnosis).
THRESHOLD = 0.39

# Operating point khusus FOTO TANGAN PENUH (subjek PCD): threshold diturunkan
# supaya sens >= 0.85 tercapai di rantai PCD->crop->RF (ukur di 250 foto
# figshare: pcd_mean @ 0.25 -> sens 0.855 spec 0.503; lihat README seksi
# "Rantai end-to-end PCD->ML"). Untuk foto kuku close-up tetap pakai THRESHOLD.
THRESHOLD_HAND = 0.25

# Resep inferensi rantai tangan penuh yang terukur (AUC 0.794 di figshare):
# top-2 kotak kandidat per fingertip peak, agregasi prob = mean (+ median).
KEEP_K = 2

model = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global model
    if MODEL_PATH.exists():
        model = joblib.load(MODEL_PATH)
        print(f"[ml] model dimuat: {MODEL_PATH.name}")
    else:
        print("[ml] WARNING: rf_model.joblib belum ada - jalankan train.py dulu")
    yield


app = FastAPI(title="Anemia Care - ML Sidecar", version="0.1.0", lifespan=lifespan)


class PredictResponse(BaseModel):
    label: str
    probability: float = Field(ge=0.0, le=1.0)
    hb_estimate_gdl: float | None
    model: str


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}


@app.post("/predict", response_model=PredictResponse)
async def predict(file: UploadFile = File(...)):
    if model is None:
        raise HTTPException(503, "Model belum dimuat - jalankan train.py dulu")
    try:
        img = Image.open(BytesIO(await file.read()))
        img = img.convert("RGB")
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(400, "File bukan gambar valid") from exc

    img = img.resize((224, 224), Image.LANCZOS)
    rgb = np.asarray(img, dtype=np.uint8)
    feats = extract_features(rgb).reshape(1, -1)
    prob = float(model.predict_proba(feats)[0, 1])
    return PredictResponse(
        label="anemia" if prob >= THRESHOLD else "normal",
        probability=round(prob, 4),
        hb_estimate_gdl=None,
        model="rf_v1",
    )


class HandPredictResponse(BaseModel):
    label: str
    probability: float = Field(ge=0.0, le=1.0)
    probability_median: float = Field(ge=0.0, le=1.0)
    n_nails: int
    model: str


def _pcd_available() -> bool:
    try:
        import pcd_core  # noqa: F401
        return True
    except ImportError:
        return False


def _best_nails(img_bgr):
    """PCD pada orientasi asli + 3 rotasi; pilih versi dengan kandidat terbanyak.

    PCD diasumsikan jari menghadap ke atas (fingertip = top-edge peak). Foto
    nyata tidak selalu portrait persis -> coba rotasi, ambil yang paling yakin.
    """
    from pcd_core import find_nails, segment_skin
    best_img, best_cands = img_bgr, []
    for rot in (None, cv2.ROTATE_90_CLOCKWISE,
                cv2.ROTATE_180, cv2.ROTATE_90_COUNTERCLOCKWISE):
        img = img_bgr if rot is None else cv2.rotate(img_bgr, rot)
        cands = find_nails(segment_skin(img), img)
        if len(cands) > len(best_cands):
            best_img, best_cands = img, cands
    return best_img, best_cands


def _crop_proba(img_bgr, box):
    """Crop kandidat -> 224 LANCZOS -> RGB -> fitur 33D -> proba (replika serving)."""
    x1, y1, x2, y2 = map(int, box)
    x1, y1 = max(0, x1), max(0, y1)
    crop = img_bgr[y1:y2, x1:x2]
    if crop.size == 0:
        return None
    pil = Image.fromarray(cv2.cvtColor(crop, cv2.COLOR_BGR2RGB))
    pil = pil.resize((224, 224), Image.LANCZOS)
    rgb = np.asarray(pil, dtype=np.uint8)
    feats = extract_features(rgb).reshape(1, -1)
    return float(model.predict_proba(feats)[0, 1])


@app.post("/predict-hand", response_model=HandPredictResponse)
async def predict_hand(file: UploadFile = File(...)):
    """Kontrak: foto TANGAN PENUH (multiple fingers).

    Alur: PCD deteksi kuku (mask kulit HSV + grid fingertip) -> top-2 box per
    peak -> crop -> fitur 33D -> RF per kuku -> prob pasien = mean (+ median).
    Label memakai THRESHOLD_HAND (operating point sens>=0.85 pada 250 foto
    figshare, AUC 0.794). Output tetap indikasi awal, bukan diagnosis.
    """
    if model is None:
        raise HTTPException(503, "Model belum dimuat - jalankan train.py dulu")
    if not _pcd_available():
        raise HTTPException(503, "Dependensi PCD belum terpasang - jalankan: pip install scipy")
    try:
        img = Image.open(BytesIO(await file.read())).convert("RGB")
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(400, "File bukan gambar valid") from exc

    img_bgr = cv2.cvtColor(np.asarray(img, dtype=np.uint8), cv2.COLOR_RGB2BGR)
    best_img, cands = _best_nails(img_bgr)
    if not cands:
        raise HTTPException(
            400,
            "Kuku tidak terdeteksi pada foto. Gunakan foto tangan dengan jari "
            "menghadap ke atas, pencahayaan cukup, dan latar bersih.",
        )

    # top-2 per peak (resep rantai terukur AUC 0.794 di figshare)
    cands.sort(key=lambda c: (c["peak"], -c["score"]))
    per_peak, keep = {}, []
    for c in cands:
        if per_peak.get(c["peak"], 0) < KEEP_K:
            per_peak[c["peak"]] = per_peak.get(c["peak"], 0) + 1
            keep.append(c)
    probs = [p for p in (_crop_proba(best_img, c["bbox"]) for c in keep) if p is not None]
    if not probs:
        raise HTTPException(
            400, "Region kuku yang terdeteksi terlalu kecil untuk dianalisis."
        )

    prob = float(np.mean(probs))
    prob_median = float(np.median(probs))
    return HandPredictResponse(
        label="anemia" if prob >= THRESHOLD_HAND else "normal",
        probability=round(prob, 4),
        probability_median=round(prob_median, 4),
        n_nails=len(probs),
        model="rf_v1_pcd",
    )