# Layout & Responsive Design — selesai (Modul 7)

Modul 7 selesai: teori dari materi dosen (layout-responsive.html) diterapkan dengan meng-upgrade `lib/main.dart` menjadi **Dashboard Anemia** yang responsif. Widget baru yang dipakai: SafeArea, LayoutBuilder (menu grid 2 kolom <600px, 4 kolom >=600px), ListView.builder + GridView.count (dua-duanya `shrinkWrap` + `NeverScrollableScrollPhysics` di dalam SingleChildScrollView), Stack+Positioned (dot status pada avatar), Expanded (3 kartu statistik 1:1:1), MediaQuery (SnackBar ukuran layar dari tombol AppBar). Logika lama kepake: `where`/collection dari M5 untuk hitung pasien anemia. `flutter test` pass (verifikasi jumlah label ANEMIA = 3 dari 6 pasien), `flutter analyze` No issues.

## Implications
- Constraint flow dipahami praktis: seluruh kesalahan unbounded/overflow dapat dicegah dengan pattern `SingleChildScrollView` + `shrinkWrap` + `NeverScrollableScrollPhysics` untuk konten bersarang.
- LayoutBuilder vs MediaQuery dibedakan jelas (parent constraint vs ukuran layar) — dasar untuk layout HP-vs-tablet di app dan bekal Modul 8+.
- App sekarang sudah berbentuk dashboard dengan data statis; Modul 8 (Navigation & Routing) akan menghidupkan menu grid → halaman detail. Pola "data nempel di StatelessWidget" juga mulai terlihat limitnya → tema state management Modul 9.
- Test sekarang mengecek DATA (jumlah ANEMIA) bukan cuma teks — mulai bergeser ke "behavioral test".
- Zona perkembangan berikutnya: Navigation & Routing (Modul 8) — Navigator.push, named routes, pass data antar halaman. Menu "Riwayat/Jadwal/Input Lab" dari dashboard perlu halaman tujuannya.