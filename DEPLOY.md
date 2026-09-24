# Deploy & Runbook — Anemia Care

Panduan menjalankan stack lengkap (skrining foto kuku end-to-end) di luar emulator:
**backend NestJS + ML sidecar (FastAPI) + Postgres** via Docker Compose, lalu
**APK untuk HP fisik** dan **web admin**.

## 1. Arsitektur

```
HP (Flutter) ──http──▶ api:3000 (NestJS) ──▶ ml:8000 (FastAPI, RF 33D)
                         │                     │
                         ├──▶ db:5432 (Postgres: screening, pasien, DW trigger)
                         └──▶ web admin (React+Vite, login petugas)
```

Port penting: `api` dipublikasikan di `3000` dan `3007` (3007 = port stabil
untuk dev/emulator), `ml` di `8000`, `db` internal.

## 2. Deploy backend (server / VM)

Prasyarat: Docker Engine + Docker Compose (v2), akses root/sudo.

```bash
git clone https://github.com/xzael24/anemia-care.git
cd anemia-care
```

**WAJIB ganti secret produksi** (jangan pakai nilai default dev!):

| Variabel | Lokasi | Default dev (jangan dipakai) | Produksi |
|---|---|---|---|
| `JWT_SECRET` | `docker-compose.yml` (api.environment) | `anemia-care-jwt-secret-2026` | `openssl rand -hex 32` |
| `ADMIN_USERNAME` | `docker-compose.yml` (api.environment) | `admin` | username admin unik |
| `ADMIN_PASSWORD` | `docker-compose.yml` (api.environment) | `admin123` | password kuat (≥ 12 karakter) |
| `POSTGRES_PASSWORD` / `DB_PASSWORD` | `docker-compose.yml` (db & api) | `anemia` | password DB kuat |

Contoh memakai env produksi tanpa mengedit file (overwrite via shell):

```bash
export JWT_SECRET="$(openssl rand -hex 32)"
export ADMIN_USERNAME="admin_kader"
export ADMIN_PASSWORD="GantiIni!2026"
export DB_PASSWORD="GantiJuga!DB2026"

docker compose up -d --build
docker compose ps          # semua harus healthy/up
curl http://localhost:3007/api/health   # {"status":"ok",...}
```

Verifikasi login petugas:

```bash
curl -X POST http://localhost:3007/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin_kader","password":"GantiIni!2026"}'
# -> {"accessToken": "..."}
```

> ⚠️ Jika `db` dipakai ulang dari volume lama dengan `DB_PASSWORD` baru, hapus
> volume dulu: `docker compose down -v` (data skrining/pasien ikut terhapus).

## 3. APK untuk HP fisik

Default base URL app adalah `http://10.0.2.2:3007/api` (**hanya jalan di Android
emulator**). Untuk HP asli, build dengan IP server/LAN:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://<IP_SERVER>:3007/api
```

- HP dan server harus satu jaringan yang bisa saling reach (LAN demo / Wi-Fi kelas).
- `<IP_SERVER>`: IP LAN host (mis. `192.168.56.101`, `192.168.1.10`).
- Hasil: `build/app/outputs/flutter-apk/app-release.apk`.

**Alternatif USB (tanpa IP LAN):** `adb reverse tcp:3007 tcp:3000` lalu build
dengan `--dart-define=API_BASE_URL=http://localhost:3007/api`.

## 4. Web admin

```bash
cd web_admin
npm ci
VITE_API_URL=http://<IP_SERVER>:3007/api npm run build   # -> dist/
```

Serve `dist/` dengan server statis apa pun (nginx, `npx serve dist`, dll).

## 5. Verifikasi end-to-end

1. Buka web admin (IP server) → login petugas → lihat riwayat + tren DW.
2. Di HP/emulator: **Daftar akun pasien** → buka tab Skrining → pilih foto kuku →
   hasil indikasi awal + rekomendasi → cek riwayat di menu akun.
3. Cek DW: `GET /api/dw/summary` (token admin) → `pasien/perempuan/laki` terisi.

## 6. Hardening & catatan produksi

- **Semua output adalah indikasi awal skrining, bukan diagnosis** — disclaimer
  sudah ada di app/web; jangan dihapus.
- Skema HTTP (plaintext) hanya untuk demo/LAN. Untuk publik, pasang reverse
  proxy **Caddy/Nginx dengan HTTPS** di depan `api` dan build APK dengan
  `--dart-define=API_BASE_URL=https://domain/api`. (App memakai `dart:io` —
  kebijakan `usesCleartextTraffic` Android tidak relevan.)
- `8000` (ML) sebaiknya **tidak** diekspos publik — hanya dipakai internal oleh `api`.
- Firewall: cukup buka `3007` (atau 443 via proxy) untuk jaringan demo; `5432`
  tidak boleh terekspos keluar host.
- Backups: volume `anemia_pgdata` berisi seluruh data skrining/pasien — backup
  rutin jika dipakai produksi.