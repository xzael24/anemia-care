# Variabel & Tipe Data di Dart — selesai (Modul 3)

Modul 3 selesai: teorinya diambil dari materi dosen (variabel.html) dan dipraktikkan langsung di `bin/variabel_anemia.dart` dengan tema data pasien anemia (nama, hemoglobin, trombosit, gejala, hasil lab). Semua topik modul tercakup: deklarasi (`var` / eksplisit / `final` / `const`), tipe dasar (`int`, `double`, `num`, `String`, `bool`, `dynamic`), string interpolation (`$var`, `${expr}`), collection (`List`, `Map`, `Set`), null safety (`?`, `?.`, `??`), dan konversi tipe (`double.parse`, `toStringAsFixed`, `toInt`). `dart run` output sesuai ekspektasi, `flutter analyze` No issues.

## Implications
- Fondasi bahasa sudah aman untuk lanjut: Modul 4 (Function & OOP) akan memakai semua ini — terutama tipe parameter & return (sudah kelihatan dari helper `cekLabLama() => null` yang gue sisipkan sebagai bridge ke materi fungsi).
- Pelajaran lint: analyzer menangkap (a) duplicate di set literal, (b) `?.` yang statis ketahuan non-null/null (dead code), (c) variabel tak terpakai. Menulis kode yang *lolos analyze* itu standar; perbaiki peringatan, bukan di-ignore (kecuali sengaja + diberi komentar).
- Cutoff untuk nilai medis: `toInt()` memotong desimal — untuk hemoglobin harus `double`, jangan pernah `int`. Ini keputusan desain penting buat app anemia.
- Zona perkembangan berikutnya: function & OOP (Modul 4) — mahasiswa sudah sering liat `void main()` dan helper function, tinggal di-resmi-in konsepnya.