# Function & OOP di Dart — selesai (Modul 4)

Modul 4 selesai: teori dari materi dosen (fungsi-oop.html) dipraktikkan di `bin/fungsi_oop_anemia.dart` bertema skrining anemia. Semua topik modul dikerjakan: function + arrow syntax, named/required/optional-positional parameters, class `Pasien` (properties, constructor, getter, method, encapsulation `_kode`), inheritance & polymorphism (`Skrining` abstract → `SkriningAnemia`/`SkriningKelelahan` dengan `@override`), abstract class dengan method konkret (`ringkasan()`), dan mixin dengan state (`TercatatDiRekamMedis`). Output `dart run` benar, `flutter analyze` No issues.

## Implications
- Frame kerja untuk modul UI: widget = class, constructor pakai named parameters. Mahasiswa sudah punya bekal sebelum `MetricText`/`TextStyle(nama: ...)` di Modul 6+.
- Lint `prefer_initializing_formals` muncul karena param publik `kode` dialiaskan ke field privat `_kode` — di-ignore dengan komentar berjatah (param `super.kode` di subclass butuh nama publik itu). Pelajaran: ignore lint itu boleh kalau disengaja + dijelaskan, bukan karena males.
- `super.kode` (super parameters, Dart 3) sudah kepakai di `PasienTercatat` tanpa perlu nulis ulang field — ini fitur modern yang menyederhanakan inheritance.
- Pola "abstract class + method konkret bawaan" (`ringkasan()`) bakal berguna banget buat app anemia: satu titik logika, semua tipe skrining ikut, tapi perilaku spesifik masing-masing.
- Zona perkembangan berikutnya: Collection & Async (Modul 5) — list comprehension/filter/map serta Future/async-await yang jadi fondasi pengambilan data (jantung app anemia: ambil data pasien dari API/database).