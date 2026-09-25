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

## Temuan evaluasi — keterbatasan domain (2026-09-25)

Uji empiris foto di luar domain training (lihat `NOTES.md`):

| Input | Prob (RF) | Label | Catatan |
|---|---|---|---|
| Crop kuku kaggle anemia (`ghana_anemic_Fin-008_4`) | 0.93 | anemia ✅ | sesuai domain training |
| Crop kuku kaggle normal (`nature_102_0`) | 0.02 | normal ✅ | sesuai domain training |
| Foto tangan penuh figshare, Hb 4.4 g/dL (`288.jpg`) | 0.32 | normal ❌ | di luar domain |
| Crop kuku figshare (bbox metadata), Hb 4.4 vs 16.9 | 0.47 vs 0.62 | anemia ❌ | terbalik / tanpa separasi |
| Crop kuku figshare + mask background | 0.41 vs 0.41 | anemia ❌ | nol separasi |

**Kesimpulan:** model **valid pada foto kuku close-up** (kuku mengisi frame,
seperti data training ghana/nature). Model **gagal pada foto di luar domain**
(foto tangan penuh, foto ilmiah ber-kartu kalibrasi, pencahayaan berbeda)
karena fitur 33D adalah warna mentah yang sensitif terhadap white-balance &
background — tanpa kalibrasi warna dan tanpa isolasi kuku.

**Implikasi:**
1. App mewajibkan foto close-up ("Kuku mengisi frame") — sudah ada di
   `lib/screens/skrining_screen.dart`.
2. Roadmap PCD di bawah (segmentasi kuku + kalibrasi warna) menjadi prasyarat
   agar serving tahan terhadap foto non-close-up. Hasil uji ini adalah bukti
   evaluasi untuk laporan capstone (kejujuran model + arah iterasi).

## PCD: segmentasi kuku otomatis (2026-09-25) — evaluasi vs GT figshare

Pipeline prototipe di `pcd_segment_eval.py` (mask kulit HSV → profil
`top_edge` → peak fingertip → grid kotak kandidat 50×55):

- Filter body **column occupancy** `>=0.4` (fraksi kulit pada `py..py+150`)
  menggantikan run kontigu — kuku/polish/kerutan membuat gap di kolom jari
  asli, sedangkan titik noise (tekstur kertas) occupancy-nya ~0.1.
- Peak dengan **prominence 2, distance 25** (jari pendek prom 3-6; distance
  >=30 menggabungkan jari yang berdekatan → peak tunggal).
- Grid **multi-offset vertikal** `10..210` (step 25) + **x-shift ±14**:
  kuku umumnya 10-25px di bawah ujung jari, tapi minoritas besar 45-210px
  (jari miring/pendek), dan pusat kuku bisa ~20px di luar kolom fingertip.
- Per-peak top-10 + cap global 45; ranking final oleh greedy IoU matching.

**Hasil (250 foto figshare, cocok IoU>=0.5, greedy):**

| Metrik | Nilai |
|---|---|
| Recall@0.5 (per GT box) | **0.657** (493/750) |
| Per-image recall@0.5 (mean / median) | 0.657 / 0.667 |
| Foto recall sempurna (recall=1.0) | 50/250 (20%) |
| Foto recall=0 | 3/250 (1.2%) |
| Precision@0.5 | 0.053 |
| Mean IoU (matched boxes) | 0.594 (n=605) |

**Batas jujur:** precision rendah karena skor kuku (`1 - skin_frac`) nyaris
tidak mendiskriminasi — GT center kuku figshare 98.9% di dalam mask kulit
(kuku skin-colored, tanpa lubang) sehingga ranking antar-sibling grid
hampir acak; cap global hanya memangkas noise kasar, FP dominan. Deteksi
tetap berguna sebagai *localizer*: recall 0.657 mengalahkan target ~0.5,
IoU matched 0.594 cukup untuk crop kuku. Sisa 3 foto recall=0 dan
near-miss (IoU 0.24-0.37) adalah kuku yang terletak sangat jauh dari
profil ujung jari (jari hampir rata/sejajar frame). Evaluasi dilakukan
penuh pada set tes (bukan hold-out) — angka di atas adalah ceiling dengan
pendekatan HSV+grid ini, bukan klaim generalisasi.

## Roadmap (belum dikerjakan)

- [x] Segmentasi kuku (PCD): bbox otomatis — prototipe dievaluasi (lihat seksi PCD);
      integrasi crop kuku ke pipeline fitur belum
- [ ] Normalisasi pencahayaan (CLAHE/Retinex) + kalibrasi white balance
- [ ] Estimasi Hb (regresi, subset nature) sebagai pendukung
- [ ] Rilis CNN / ensemble RF+CNN sebagai alternatif model
- [ ] Dockerfile + compose (backend + ml_service + db) untuk deploy cloud