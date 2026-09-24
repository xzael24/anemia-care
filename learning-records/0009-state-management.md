# State Management — selesai (Modul 9)

Modul 9 selesai: teori dari materi dosen (state-management.html) diterapkan. Tantangan TodoList diadaptasi menjadi **Jadwal Pemantauan**: package `provider` 6.1.5 ditambahkan, `lib/models/jadwal_model.dart` berisi `JadwalModel extends ChangeNotifier` (items, getter total/jumlahBelumSelesai/jumlahSelesai/persentaseSelesai, tambah dengan tolak-duplikat, toggle, hapus, hapusSemuaSelesai). `AnemiaApp` kini membungkus `ChangeNotifierProvider`. Tab Jadwal membaca state dengan `context.watch` (CheckboxListTile untuk centang selesai, tombol hapus, "Hapus Semua Selesai", counter belum-selesai di AppBar). Dashboard "Catat ke Jadwal" (hasil pop Modul 8) kini menyimpan ke state dengan `context.read`. Halaman `StatistikPage` baru (route `/statistik`) membaca **Provider yang sama** — jawaban untuk tantangan dosen no.3. `flutter test` 5 pass (1 unit test model baru + 4 widget test), `flutter analyze` No issues.

## Implications
- **State keluar dari widget**: `_pasien` di dashboard masih statis, tapi data yang hidup (jadwal) sudah global di satu sumber. Batas Modul 8 yang tercatat di learning record 0008 memang dipecahkan di sini — bukti pola "catat zona perkembangan, tutup di modul berikutnya" bekerja.
- `watch` vs `read` dibedakan ketat sejak awal: watch di build (rebuild), read di event handler (tanpa rebuild). Ini mencegah dua bug klasik: rebuild berlebihan dan ProviderNotFoundError saat read di build.
- Provider ditaruh di `AnemiaApp.build` (bukan `main()`) — pola yang membuat setiap `pumpWidget(const AnemiaApp())` di test mendapat model segar; isolasi test terjaga tanpa setup tambahan.
- Unit test model pertama dibuat (`test/jadwal_model_test.dart`) — logika murni diuji tanpa widget. Fondasi untuk Modul 13 (Testing) yang bakal dalami ini.
- Deviasi dicatat eksplisit: tombol "Hapus Semua Selesai" dipindah dari bottom bar ke bawah daftar karena shell sudah punya NavigationBar — contoh keputusan adaptif dengan alasan, bukan asal ubah.
- Zona perkembangan berikutnya: REST API & HTTP (Modul 10) — data pasien masih hardcoded di dashboard; modul depan menggantinya dengan data dari server (http package, JSON, FutureBuilder). JadwalModel siap jadi tempat nyimpen hasil fetch.</think>

<｜DSML｜tool_calls>
<｜DSML｜invoke name="write">
<｜DSML｜parameter name="content" string="true"># State Management — selesai (Modul 9)

Modul 9 selesai: teori dari materi dosen (state-management.html) diterapkan. Tantangan TodoList diadaptasi menjadi **Jadwal Pemantauan**: package `provider` 6.1.5 ditambahkan, `lib/models/jadwal_model.dart` berisi `JadwalModel extends ChangeNotifier` (items, getter total/jumlahBelumSelesai/jumlahSelesai/persentaseSelesai, tambah dengan tolak-duplikat, toggle, hapus, hapusSemuaSelesai). `AnemiaApp` kini membungkus `ChangeNotifierProvider`. Tab Jadwal membaca state dengan `context.watch` (CheckboxListTile untuk centang selesai, tombol hapus, "Hapus Semua Selesai", counter belum-selesai di AppBar). Dashboard "Catat ke Jadwal" (hasil pop Modul 8) kini menyimpan ke state dengan `context.read`. Halaman `StatistikPage` baru (route `/statistik`) membaca **Provider yang sama** — jawaban untuk tantangan dosen no.3. `flutter test` 5 pass (1 unit test model baru + 4 widget test), `flutter analyze` No issues.

## Implications
- **State keluar dari widget**: `_pasien` di dashboard masih statis, tapi data yang hidup (jadwal) sudah global di satu sumber. Batas Modul 8 yang tercatat di learning record 0008 memang dipecahkan di sini — bukti pola "catat zona perkembangan, tutup di modul berikutnya" bekerja.
- `watch` vs `read` dibedakan ketat sejak awal: watch di build (rebuild), read di event handler (tanpa rebuild). Ini mencegah dua bug klasik: rebuild berlebihan dan ProviderNotFoundError saat read di build.
- Provider ditaruh di `AnemiaApp.build` (bukan `main()`) — pola yang membuat setiap `pumpWidget(const AnemiaApp())` di test mendapat model segar; isolasi test terjaga tanpa setup tambahan.
- Unit test model pertama dibuat (`test/jadwal_model_test.dart`) — logika murni diuji tanpa widget. Fondasi untuk Modul 13 (Testing) yang bakal dalami ini.
- Deviasi dicatat eksplisit: tombol "Hapus Semua Selesai" dipindah dari bottom bar ke bawah daftar karena shell sudah punya NavigationBar — contoh keputusan adaptif dengan alasan, bukan asal ubah.
- Zona perkembangan berikutnya: REST API & HTTP (Modul 10) — data pasien masih hardcoded di dashboard; modul depan menggantinya dengan data dari server (http package, JSON, FutureBuilder). JadwalModel siap jadi tempat nyimpen hasil fetch.