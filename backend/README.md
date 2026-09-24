# Anemia Care API (NestJS)

Backend untuk aplikasi **Anemia Care** — skrining anemia non-invasif dari foto kuku.

> ⚠️ Hasil skrining adalah **indikasi awal, BUKAN diagnosis medis**. Disclaimer selalu
> disertakan di setiap respons `/api/screening`.

## Stack

- **NestJS 11** (TypeScript) — backend utama (REST API)
- `@nestjs/config` — konfigurasi via `.env`
- `@nestjs/terminus` — health check
- Multer (built-in platform-express) — upload foto
- Sidecar ML (FastAPI) — opsional, dipanggil via HTTP; lihat [kontrak](#kontrak-sidecar-ml)

## Menjalankan

```bash
npm install
cp .env.example .env   # sesuaikan kalau perlu
npm run start:dev      # http://localhost:3000/api
```

Build produksi: `npm run build && npm run start:prod`

## Menjalankan lengkap (backend + ML sidecar)

1. Siapkan model & mulai sidecar (detail: `../ml_service/README.md`):

   ```bash
   cd ../ml_service
   python -m venv .venv && .venv\Scripts\activate   # sekali saja
   pip install -r requirements.txt                  # sekali saja
   python train.py                                  # sekali saja -> rf_model.joblib
   uvicorn app:app --host 0.0.0.0 --port 8000
   ```

2. Set `ML_SERVICE_URL=http://localhost:8000` di `.env` (atau env var).
3. Jalankan backend — `POST /api/screening` kini mengembalikan prediksi nyata
   (`source: "ml"`), bukan simulasi.

## Endpoint

| Method | Path                | Keterangan                                        |
|--------|---------------------|---------------------------------------------------|
| GET    | `/api/health`       | Health check (heap memory)                        |
| POST   | `/api/screening`    | Upload foto (field `photo`) → hasil skrining      |
| GET    | `/api/screening`    | Riwayat skrining (v0: in-memory, maks 100 entri)  |

### POST /api/screening — contoh

```bash
curl -F "photo=@kuku.jpg" http://localhost:3000/api/screening
```

```json
{
  "id": "c8f7...",
  "indication": "anemia",
  "confidence": 0.58,
  "hbEstimateGdl": null,
  "source": "mock",
  "imageName": "kuku.jpg",
  "createdAt": "2026-09-24T07:20:00.000Z",
  "disclaimer": "Hasil ini adalah indikasi awal skrining non-invasif, BUKAN diagnosis medis. ..."
}
```

`source` bernilai:
- `"ml"` — prediksi dari sidecar ML sungguhan
- `"mock"` — mode simulasi (ML_SERVICE_URL kosong / sidecar gagal), **bukan hasil diagnosis**

## Kontrak sidecar ML

Sidecar (FastAPI) menerima multipart `file` di `/predict`:

```json
200 OK
{
  "label": "anemia" | "normal",
  "probability": 0.87,
  "hb_estimate_gdl": 11.2,
  "model": "rf_v1"
}
```

Materi ML berada di `../capstone/` (folded mirror dari repo CAPSTONE: dataset, model
artifacts, skrip training).

## Testing

```bash
npm test          # unit test (MlService fallback/deterministik)
npm run test:e2e  # e2e (health, screening validasi + mode mock)
```

## Roadmap (belum dikerjakan)

- [ ] Persistensi riwayat (Prisma + SQLite lokal / Postgres/Supabase utk cloud)
- [ ] Auth (JWT) — petugas kesehatan/admin
- [x] Sidecar ML FastAPI (RandomForest feature-based, `../ml_service/`) — jalan lokal
- [ ] Docker compose (backend + ml_service + db) untuk deploy cloud
- [ ] Integrasi Flutter app (dio) ke endpoint ini
- [ ] Web admin dashboard (Flutter web / React)