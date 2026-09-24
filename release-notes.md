## Anemia Care v1.0.0 🩸

Rilis pertama **Anemia Care** — aplikasi pemantauan anemia hasil 15 modul Mobile Programming (Flutter).

### ✨ Fitur utama
- 📊 **Dashboard** — ringkasan pasien & status anemia (batas Hb 12.0 g/dL, klasifikasi normal/ringan/sedang/berat)
- 📅 **Jadwal Pemantauan** — persisten di SQLite, tandai selesai, statistik kelengkapan
- 📇 **Direktori Pasien** — REST API (JSONPlaceholder), detail + tambah pasien
- 🖼️ **Galeri Hasil Lab** — foto dari kamera/galeri, timestamp otomatis, hapus long-press
- 🧭 **Navigasi** — 4 tab dengan tab terakhir tersimpan (SharedPreferences)
- 🧪 **35 test** (unit + widget) dengan cakupan 86.6% baris `lib/`

### 📦 File
| File | Keterangan | Ukuran |
|---|---|---|
| `app-release.apk` | APK universal (semua arsitektur) | 50.4 MB |
| `app-arm64-v8a-release.apk` | APK untuk kebanyakan HP modern (ARM64) | 17.8 MB |
| `app-release.aab` | Android App Bundle (untuk Play Store) | 49.4 MB |

### 📲 Install
1. Unduh salah satu file APK di atas.
2. Buka file di HP Android → izinkan **"Install dari sumber tidak dikenal"**.
3. Selesai — app muncul dengan ikon droplet `🩸`.

> ⚠️ **Disclaimer**: project ini dibuat untuk tugas mata kuliah, bukan pengganti diagnosis medis. Klasifikasi anemia mengikuti ambang WHO dewasa — konsultasikan dengan tenaga kesehatan untuk keputusan medis.