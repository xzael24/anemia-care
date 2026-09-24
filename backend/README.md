# Anemia Care API (NestJS)

Backend untuk aplikasi **Anemia Care** — skrining anemia non-invasif dari foto kuku.

> ⚠️ Hasil skrining adalah **indikasi awal, BUKAN diagnosis medis**. Disclaimer selalu
> disertakan di setiap respons `/api/screening`.

## Stack

- **NestJS** (TypeScript) — backend utama (REST API)
- **TypeORM + Postgres 16** — persistensi riwayat skrining & akun petugas
  (aktif saat `DB_HOST` di-set; tanpa itu → in-memory untuk tes)
- **JWT (jsonwebtoken) + bcryptjs** — auth petugas/admin
- `@nestjs/config` — konfigurasi via `.env`
- `@nestjs/terminus` — health check
- Multer (platform-express) — upload foto
- Sidecar ML (FastAPI) — opsional, dipanggil via HTTP; lihat [kontrak](#kontrak-sidecar-ml)

## Menjalankan

```bash
npm install
cp .env.example .env   # sesuaikan kalau perlu
npm run start:dev      # http://localhost:3000/api
```

Build produksi: `npm run build && npm run start:prod`

## Menjalankan lengkap (backend + ML sidecar + Postgres)

Cara termudah: **Docker Compose** di root repo (`../docker-compose.yml`) —
`api` + `ml` + `db` sekaligus, termasuk seed admin:

```bash
cd ..
docker compose up -d --build
# login: admin / admin123 (ubah ADMIN_PASSWORD di env produksi)
```

Manual: sidecar dulu (lihat `../ml_service/README.md`), set `ML_SERVICE_URL`,
lalu jalankan backend dengan `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASSWORD`/`DB_NAME`.

## Endpoint

| Method | Path                | Akses        | Keterangan                                      |
|--------|---------------------|--------------|-------------------------------------------------|
| GET    | `/api/health`       | Publik       | Health check (heap memory)                      |
| POST   | `/api/screening`    | Publik       | Upload foto (field `photo`) → hasil skrining    |
| GET    | `/api/screening`    | `admin`/`petugas` | Riwayat skrining (Postgres, max 100)       |
| PATCH  | `/api/screening/:id/verify` | `admin`/`petugas` | Verifikasi hasil (human-in-the-loop)   |
| POST   | `/api/auth/login`   | Publik       | Login → `{ accessToken, petugas }` (JWT 8 jam)  |
| GET    | `/api/auth/me`      | Token        | Info petugas yang login                         |

Login contoh:

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
# → { "accessToken": "eyJ...", "expiresIn": "8h", "petugas": { ... } }

curl http://localhost:3000/api/screening \
  -H "Authorization: Bearer <accessToken>"
```

### POST /api/screening — contoh

```bash
curl -F "photo=@kuku.jpg" http://localhost:3000/api/screening
```

```json
{
  "id": "c8f7...",
  "indication": "anemia",
  "confidence": 0.92,
  "hbEstimateGdl": null,
  "source": "ml",
  "imageName": "kuku.jpg",
  "createdAt": "2026-09-24T07:20:00.000Z",
  "disclaimer": "Hasil ini adalah indikasi awal skrining non-invasif, BUKAN diagnosis medis. ..."
}
```

`source` bernilai:
- `"ml"` — prediksi dari sidecar ML sungguhan (RandomForest 33D)
- `"mock"` — mode simulasi (ML_SERVICE_URL kosong / sidecar gagal), **bukan hasil diagnosis**

## Auth (JWT)

- Login valid → token HS256 (`JWT_SECRET`, default dev `anemia-care-dev-secret`), 8 jam.
- Route riwayat dilindungi `JwtAuthGuard` + `RolesGuard` (`@Roles('admin','petugas')`).
- Password di-hash bcrypt (cost 10); admin default di-seed saat tabel `petugas` kosong
  (`ADMIN_USERNAME`/`ADMIN_PASSWORD`, default `admin`/`admin123` — **ganti di produksi**).

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

Materi ML berada di `../capstone/` (mirror dari repo CAPSTONE: dataset, model
artifacts, skrip training).

## Testing

```bash
npm test          # unit: MlService (fallback/deterministik) + AuthService (login)
npm run test:e2e  # e2e: health, validasi screening, auth (401/201/200 + riwayat)
```

## Roadmap (belum dikerjakan)

- [x] Sidecar ML FastAPI (RandomForest feature-based, `../ml_service/`)
- [x] Docker compose (`api` + `ml` + `db`) untuk deploy lokal/VM cloud
- [x] Persistensi riwayat (Postgres, TypeORM) + auth JWT petugas/admin
- [ ] Integrasi Flutter app (dio) ke endpoint ini
- [ ] Web admin dashboard (Flutter web / React)
- [ ] DW star schema di Postgres yang sama