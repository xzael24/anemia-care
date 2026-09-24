# Build APK & AAB (Release) — selesai (Modul 14)

Modul 14 selesai: app dikasih identitas rilis yang proper dan — yang paling penting — **build gradle AKHIRNYA berhasil di mesin 7.7GB** (sejak M2 selalu collapse OOM; sekarang setting `-Xmx1536m` + daemon jvmargs + build background jalan mulus).

## Yang dikerjakan

1. **Nama aplikasi** — `AndroidManifest.xml`: `android:label="Anemia Care"` (sebelumnya "anemia" huruf kecil, kurang proper di home screen).
2. **Application ID** — `build.gradle.kts`: `applicationId = "id.anemiacare.app"` (format reverse-domain, menggantikan `com.example.anemia`). **Catatan keras:** ID nggak bisa diubah setelah publish pertama — jadi `id.anemiacare.app` masih placeholder; ganti ke domain beneran sebelum upload Play Store. `namespace` sengaja tetap `com.example.anemia` (internal, nggak ngaruh Play Store) biar nggak perlu mindahin MainActivity ke package baru.
3. **Ikon & splash DIGENERATE, bukan didesign** — `tool/gen_icon.dart`: script Dart murni (nggak ada dependency image processing) yang:
   - menggambar droplet merah (#D32F2F) di gradient pink muda → background transparan untuk splash,
   - nge-encode PNG sendiri (signature + IHDR + IDAT dengan zlib dart:io + CRC32 manual),
   - anti-aliasing via supersampling 2×2.
   Bug nyata yang ketemu: di fungsi chunk, CRC ditulis SEBELUM data → ikon nggak bisa di-decode (width kebaca `7F 1D 2B 83`). Fix urutan. Pelajaran: verifikasi binary format bikinan sendiri pakai decoder sungguhan (di sini package:image lewat flutter_launcher_icons) / dump hex.
4. **Tool resmi** — `dart run flutter_launcher_icons` (mipmap semua density + adaptive icon v26 + colors.xml) dan `flutter_native_splash:create` (drawable launch_background + styles, termasuk values-v31 buat Android 12+). Keduanya manggung di Windows tanpa masalah.
5. **Keystore & signing** — `keytool -genkeypair` (RSA 2048, valid 10000 hari): `android/app/upload-keystore.jks`, alias `upload`. Password acak 28 karakter di `android/key.properties`. `build.gradle.kts`: load properties → `signingConfigs.create("release")` → release pakai keystore upload, fallback ke debug key kalau file belum ada (proyek klonanan tetap bisa build). `.gitignore` + `android/key.properties` & `android/app/*.jks`.
6. **Build — SEMUA SUKSES:**
   - `flutter build apk --debug` → `app-debug.apk` **150.72 MB** (206s)
   - `flutter build apk --release` → `app-release.apk` **50.4 MB** (476s) + font tree-shaking: MaterialIcons 1,645,184 → 5,752 byte (**99.7%**)
   - `flutter build appbundle --release` → `app-release.aab` **49.4 MB** (109s — cache hangat dari build release)
   - `flutter build apk --release --split-per-abi` → arm64 **17.8 MB**, armeabi-v7a 15.3 MB, x86_64 19.2 MB (184s). Kontras: universal 50.4MB vs arm64 17.8MB = ≈65% lebih kecil (Play Store ngelakuin ini otomatis dari AAB).
7. **Verifikasi dari dalam APK** — `aapt dump badging` (build-tools 34.0.0):
   - `package: name='id.anemiacare.app' versionCode='1' versionName='1.0.0'` ✓
   - `application-label:'Anemia Care'` ✓, minSdk 24, targetSdk 36 ✓
   - `apksigner verify --print-certs`: Signer #1 cert DN `CN=Anemia Care, OU=Mobile Programming, O=Student, L=Bandung, ST=Jawa Barat, C=ID` — **keystore upload kita, bukan debug** ✓

## Tantangan dosen → status

| # | Tantangan | Status |
|---|-----------|--------|
| 1 | Ganti nama, applicationId, ikon, splash | ✅ (ikon & splash digenerate programmatic) |
| 2 | Keystore upload + signing config | ✅ |
| 3 | Universal APK + split arm64 + AAB + catat ukuran | ✅ universal 50.4MB; split arm64 17.8MB (+v7a 15.3, x86_64 19.2); AAB 49.4MB |
| 4 | Install di HP | ⏳ sesi user (emulator/fisik, `flutter install`) |
| 5 | Bonus obfuscate + split-debug-info | 📝 teori; minify R8 udah default di release |

## Deviasi & catatan

- **Bukan project terpisah** (dosen: `flutter_widget_dasar`/`flutter_rest_api`) — kita kasih identitas ke project anemia sendiri (keputusan awal: satu project berkembang).
- **Ikon nggak didesign** — digenerate programmatic karena nggak ada designer/asset. Jujur & reproducible: ganti warna/posisi → jalanin script → regenerate.
- **applicationId placeholder** — `id.anemiacare.app` bukan domain beneran; ganti sebelum publish (M15). `namespace` dibiarkan (keputusan minimal-risk, tercatat).
- **Sensitivitas RAM** — build gradle BERHASIL sesi ini (IDE/browser ditutup + setting memori M11): 4 build berturut-turut sukses (debug, release, AAB, split) = pipeline release stabil. M15 tinggal pakai AAB & signing yang udah siap.

## Verifikasi

- `flutter analyze`: No issues. `flutter test --concurrency=1`: 35 pass.
- APK debug & release terbentuk, release signature upload keystore, aapt badging cocok.

## Implications

- **App siap didistribusikan**: release APK installable + AAB 49.4MB + keystore aman → Play Store tinggal kelola akun (M15).
- **IDENTITAS**: nama + ikon droplet + splash = brand konsisten (juga dipakai buat final project M16).
- Zona depan: **Modul 15: Publish ke Play Store (publish-playstore.html)** — akun developer $25, Console, upload AAB, store listing, review; sebagian besar butuh akun beneran (catat jujur: bikin/tutorial review, bisa di-defer kalau nggak punya akun).