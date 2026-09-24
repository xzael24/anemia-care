# Web Admin Monitoring (Petugas/Kader)

Dashboard admin untuk memantau hasil skrining anemia dari foto kuku — dibangun dengan
**React + Vite + TypeScript**. Konsumen API `PATCH /api/screening/:id/verify` dan
`GET /api/screening` (JWT).

> ⚠️ Estafet peran: **mobile = pengguna diskrining**, **web = petugas/kader kesehatan**
> (memantau hasil + verifikasi). Keduanya berbagi satu backend NestJS (`backend/`).

## Fitur

- 🔐 **Login petugas** — `POST /api/auth/login` → JWT disimpan di `localStorage`
- 📊 **Dashboard** — kartu statistik (total, indikasi anemia/normal, terverifikasi)
- 📈 **Tren Data Warehouse** — bagan batang 14 hari terakhir dari `GET /api/dashboard/trend`
  (ETL real-time), + pill "Indikasi anemia: X%" dari `GET /api/dashboard/summary`
- 🗂️ **Riwayat skrining** — tabel (waktu, foto, indikasi, confidence, sumber, status verifikasi)
  + filter chip (Semua / Anemia / Normal)
- ✅ **Verifikasi per-skrining** (human-in-the-loop) — `PATCH /api/screening/:id/verify`,
  status → `terverifikasi`, verifikator + timestamp tersimpan di Postgres
- 🚪 Keluar (hapus token)

## Menjalankan

```bash
npm install
npm run dev          # dev server: http://localhost:5173
npm run build        # production build → dist/
```

API default: `http://localhost:3000/api` (sesuaikan dengan env `VITE_API_URL` jika berbeda,
mis. VM `http://192.168.56.101:3000/api`).

Credential default dev: `admin` / `admin123`.

## Struktur

```
src/
  api.ts             # client fetch + token (login, screenings, verify, dashboard DW)
  App.tsx            # switch login ↔ dashboard berdasarkan token
  LoginPage.tsx      # form login petugas
  DashboardPage.tsx  # statistik + tren DW (bar chart) + tabel riwayat + verifikasi
  index.css          # styling (dark topbar, kartu statistik, bagan, badge, tabel)
```

## Verifikasi E2E (Sep 2026)

Alur diuji lewat browser otomatis (agent-browser, headless Chrome) terhadap API lokal
(`localhost:3000`):

1. Buka `http://localhost:5173` → form login tampil
2. Isi `admin` / `admin123` → Masuk → dashboard tampil (kartu statistik + 2 baris riwayat)
3. Klik **Verifikasi** pada baris pertama → status `Baru` → `Diverifikasi`, kolom
   "Diverifikasi oleh" → `admin`
4. Filter **Normal** → empty state "Belum ada hasil skrining…"
5. Psql pada container `db` membuktikan baris tersimpan:
   `status = terverifikasi, verifiedBy = admin, verifiedAt = <timestamp>`