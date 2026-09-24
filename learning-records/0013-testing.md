# Testing Aplikasi Flutter (Unit, Widget, Integration) — selesai (Modul 13)

Modul 13 selesai: teori (testing.html) diterapkan. Project udah punya 18 test, jadi fokusnya **nge-rapiin & ngedalemin** — dan semua tantangan dosen diadaptasi ke konteks app.

Yang dikerjakan:
1. **Tantangan 1 → `AnemiaLogic` (lib/models/anemia_logic.dart)** — "class Kalkulator" jadi logika anemia yang beneran dipakai: `statusAnemia`, `tingkatKeparahan` (enum normal/ringan/sedang/berat sesuai batas app 12.0 g/dL), `persentaseAnemia`, `deltaHb`. Dashboard di-refactor: `_batasHbNormal` = `AnemiaLogic.batasHbNormal` → satu sumber kebenaran. **12 unit test** pakai pola dosen (group + setUp + AAA) + matcher (isTrue/isFalse/closeTo) + edge case (boundary 12.0/11.0/8.0/7.9, list kosong, ekstrem 0.0).
2. **Tantangan 2 → `ProfileCard` (lib/widgets/profile_card.dart)** — widget `{nama, email}` + avatar inisial + subtitle opsional, **dipasang beneran** di header detail Direktori (ganti CircleAvatar+row manual; email row dihapus karena udah di card). 3 widget test (tampil keduanya, subtitle, fallback '?').
3. **Tantangan 3 → UI test jadwal** — `test/jadwal_widget_test.dart`: toggle CheckboxListTile, hapus item, Hapus Semua Selesai → empty state. Level model udah ditest sejak M9; ini melengkapi level UI. Pelajaran: `find.byIcon(delete_outline)` ambigu kalau 2 item → `find.descendant(of: find.widgetWithText(CheckboxListTile, nama), ...)`.
4. **Form validation test** — materi "Login menolak email kosong" → form tambah pasien (M10): submit kosong → SnackBar merah 'Nama & email wajib diisi'.
5. **Integration test** — `integration_test/app_test.dart` (happy path: catat → toggle → hapus → kosong). Dev dependency `integration_test` harus ditambah manual `sdk: flutter` — `flutter pub add integration_test` gagal (salah ambil versi pub.dev non-null-safe). Idempoten (bersihkan sisa "selesai"). Nggak buka tab Direktori (butuh jaringan). **Belum dijalankan** (butuh emulator + gradle, RAM — diserahkan ke sesi `flutter run` user).
6. **Coverage** — `flutter test --coverage` → **86.6% baris lib/ (568/656, 16 file)**, dihitung manual dari lcov.info (genhtml/lcov nggak terpasang).

Deviasi & catatan:
- **mockito + build_runner (dosen) → MockClient package:http/testing (kita, sejak M10)** — prinsip sama (test offline, nggak hit server), hasil setara, tanpa dependency codegen. Dicatat di lesson.
- Coverage 86.6% bukan "bebas bug" — sisa 13.4% mostly error-branch & callback UI (kamera/dll) yang butuh device nyata.
- `integration_test` di pubspec butuh `sdk: flutter` eksplisit — jebakan yang bakal dipikul siapa pun yang nambah integration test.

Verifikasi: `flutter analyze` No issues; **35 test pass** (`--concurrency=1`); coverage 86.6%.

## Implications
- Fondasi testing lengkap (3 level piramida) = tiap modul berikutnya (build, publish, final) berani diubah tanpa takut regresi.
- `AnemiaLogic` sekarang class murni yang BISA dipakai UI lain (detail pasien tinggal milih: pake tingkatKeparahan/deltaHb untuk tampilan lebih dalam di final project).
- Integration test siap dijalankan kapan pun emulator aktif.
- Zona depan: **Modul 14: Build & Release (build-release.html)** — APK/AAB sign, keystore, proguard; sinkron sama catatan RAM & Developer Mode yang udah kita pelajari sejak M2/M11.