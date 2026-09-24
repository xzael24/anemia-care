<div align="center">
  <img src="assets/icon/icon.png" width="120" height="120" alt="Anemia Care logo">
  <h1>🩸 Anemia Care</h1>
  <p><b>Aplikasi pemantauan anemia berbasis Flutter</b> — catat kadar Hb, pantau jadwal, simpan hasil lab.</p>
</div>

---

**Anemia Care** adalah aplikasi mobile untuk membantu memantau kondisi anemia: mencatat nilai hemoglobin (Hb), mengklasifikasikan tingkat keparahannya, mengatur jadwal pemantauan, dan menyimpan hasil lab dalam galeri. Dibuat sebagai project mata kuliah **Mobile Programming** (16 modul, mengikuti kurikulum [arifhidayah.vercel.app](https://arifhidayah.vercel.app/flutter)) dan dikembangkan bertahap dari Modul 1–15.

## ✨ Fitur

| Fitur | Keterangan | Modul |
|---|---|---|
| 📊 **Dashboard** | Ringkasan jumlah pasien, status anemia (Normal/Anemia), menu cepat responsif | 6–7 |
| 🧭 **Navigasi** | 4 tab (Beranda/Jadwal/Info/Direktori) + drawer + named routes + tab terakhir tersimpan | 8, 11 |
| 📈 **Statistik** | Visualisasi persentase pemantauan selesai (Provider/ChangeNotifier) | 9 |
| 📅 **Jadwal Pemantauan** | Tambah/tandai selesai/hapus, persisten di SQLite | 9, 11 |
| 📇 **Direktori Pasien** | REST API (JSONPlaceholder) — list, detail, tambah pasien, error state | 10 |
| 🩸 **Logika Anemia** | Klasifikasi keparahan (normal/ringan/sedang/berat), batas Hb 12.0 g/dL | 13 |
| 🖼️ **Galeri Hasil Lab** | Foto hasil lab dari kamera/galeri, overlay tanggal, hapus (long-press) | 12 |
| 🧪 **Testing** | 35 unit/widget test + integration test + cakupan 86.6% baris `lib/` | 13 |

## 📲 Install

Unduh APK rilis dari **[Releases](https://github.com/xzael24/anemia-care/releases)**:

- `app-release.apk` — universal (semua arsitektur, **50.4 MB**)
- `app-arm64-v8a-release.apk` — khusus ARM64 (kebanyakan HP modern, **17.8 MB**)

Cara install: buka file APK di HP Android → izinkan "Install dari sumber tidak dikenal" → selesai.

## 🔧 Build dari Source

```bash
flutter pub get
flutter run                # jalanin di emulator/device
flutter test --concurrency=1   # 35 test (wajib --concurrency=1 di RAM kecil)
flutter build apk --release    # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # → app-release.aab (Play Store)
```

## 🏗️ Teknologi

[Flutter](https://flutter.dev) · [Dart](https://dart.dev) · Provider · sqflite (SQLite) · shared_preferences · http (REST/JSONPlaceholder) · image_picker · path_provider · flutter_launcher_icons · flutter_native_splash

## 📂 Struktur

```
lib/
  main.dart              # App Shell: 4 tab + Provider + named routes
  models/                # AnemiaLogic, JadwalModel, UserPasien...
  services/              # PasienService (API), JadwalStore (SQLite), GaleriLabService
  screens/               # Dashboard, Direktori, Galeri, Statistik, Tentang...
  widgets/               # ProfileCard
test/                    # 35 test (unit + widget)
integration_test/        # E2E happy path (butuh emulator)
lessons/                 # Catatan belajar 16 modul (HTML)
learning-records/        # Refleksi tiap modul
```

## ⚠️ Disclaimer

Project ini dibuat untuk keperluan **tugas mata kuliah**, bukan pengganti diagnosis medis. Klasifikasi anemia mengikuti ambang Hb 12.0 g/dL (WHO dewasa) — konsultasikan dengan tenaga kesehatan untuk keputusan medis.

---

<p align="center"><b>Anemia Care</b> · project Mobile Programming · dibuat dengan ❤️ menggunakan Flutter</p>