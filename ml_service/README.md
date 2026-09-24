# Anemia Care — ML Sidecar (FastAPI)

Sidecar inferensi untuk backend NestJS (`../backend/`). Model: **RandomForest
feature-based** (fitur warna 33D dari foto kuku → probabilitas indikasi anemia).

> ⚠️ Output = **indikasi awal skrining, BUKAN diagnosis medis** (disclaimer selalu
> disertakan backend/app).

## Alur

```
foto kuku (app) → POST /predict (multipart "file")
   → resize 224×224 → fitur 33D (persentil RGB + rasio + LAB + HSV + gray)
   → RandomForest → {"label": "anemia"|"normal", "probability": 0–1, ...}
```

Fitur 33D adalah replika persis baseline (`capstone/scripts/training/build_notebook.py`
cell 4) — sehingga prediksi serving konsisten dengan metrik evaluasi baseline
(test RF: AUC 0,846 · sens 0,789 · spec 0,771).

## Setup & training

```bash
cd ml_service
python -m venv .venv
.venv\Scripts\activate            # Windows
pip install -r requirements.txt
python train.py                   # -> rf_model.joblib + rf_report.json
```

`train.py` membaca `../capstone/data/processed/{train,val,test}.csv` + `images/`
(mirror lokal), menghitung fitur per pasien (unit analisis = pasien, anti bocor),
melatih `RandomForest(n_estimators=300, random_state=42)`, mengevaluasi val/test,
lalu menyimpan model.

## Menjalankan

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

Kontrak:
- `GET  /health` → `{"status":"ok","model_loaded":true}`
- `POST /predict` (multipart field `file`) →
  ```json
  {"label":"anemia","probability":0.87,"hb_estimate_gdl":null,"model":"rf_v1"}
  ```

## Integrasi backend

Isi `ML_SERVICE_URL=http://localhost:8000` di `../backend/.env`, lalu jalankan
keduanya. `POST /api/screening` akan memakai prediksi sungguhan (`source: "ml"`).

## Roadmap (belum dikerjakan)

- [ ] Segmentasi kuku (PCD): bbox/mask otomatis sebelum ekstraksi fitur
- [ ] Normalisasi pencahayaan (CLAHE/Retinex) + kalibrasi white balance
- [ ] Estimasi Hb (regresi, subset nature) sebagai pendukung
- [ ] Rilis CNN / ensemble RF+CNN sebagai alternatif model
- [ ] Dockerfile + compose (backend + ml_service + db) untuk deploy cloud