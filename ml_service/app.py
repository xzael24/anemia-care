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