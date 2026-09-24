# Local Storage (SQLite & SharedPreferences) — selesai (Modul 11)

Modul 11 selesai: teori (local-storage.html) diterapkan. **Dua pembeda besar:**

1. **Persist SQLite untuk jadwal pemantauan** — gap terbesar sejak M9 tertutup: `JadwalModel` sekarang nyimpen ke DB lokal. Struktur: `JadwalItem` dipisah ke file sendiri (dengan `id` + `dibuatAt`, toMap/fromMap), `JadwalStore` (interface) + `JadwalDbStore` (singleton SQLite, pola DatabaseHelper dosen), `JadwalModel` di-load pas init (`_init = _muat()`), semua operasi async + by-`id` (bukan index — urutan berubah setelah reload), UI kasih spinner lewat `siap`.
2. **SharedPreferences untuk "tab terakhir dibuka"** — bonus dosen "login persist" diadaptasi: HomeShell simpan index tab di `tab_terakhir`, pulihkan pas start. (Kita nggak punya login, jadi fitur yang jujur & terpakai harian.)

Keputusan penting & catatan:
- **Kenapa interface (`JadwalStore`)**: sqflite = plugin native yang nggak ada di widget test. Model kenal interface, test inject `InMemoryJadwalStore` (test/fakes/), produksi pakai `JadwalDbStore.instance`. Ini membuat logika bisnis bisa diuji offline DAN menutup pintu ke "mock database" tanpa dependency tambahan. AnemiaApp dapat param `jadwalStore` untuk injeksi.
- **Test "persisten" (unit)**: model1 tambah+toggle → model2 (store sama, "restart") → data kebaca. Membuktikan semantik persist tanpa SQLite beneran.
- **Widget test**: semua harus inject fake store + `SharedPreferences.setMockInitialValues({})` — ini dokumentasi live kenapa DI itu worth it.
- **Verifikasi**: `flutter analyze` No issues; **12 test pass** (2 jadwal_model unit + 3 service unit + 2 direktori widget + 5 app widget termasuk 2 baru: restore tab terakhir).

## Implications
- **Deviasi dicatat**: bonus login-persist diubah jadi tab terakhir (konteks app). Seluruh fitur M9 behaved sama, tapi sekarang persisten.
- **Bug yang nyaris masuk**: `tambah` tadinya nulis `nama` (variabel nggak ada) — ketangkap sebelum compile. Plus pelajaran M11: operasi disk = async, jadi "return-value dari setState" dan "balapan microtask" adalah kelas bug baru yang wajib diwaspadai (mitigasi: `Future get init` di model).
- **Environment blocker baru dicatat**: `flutter pub add` melempar warning "Building with plugins requires symlink support" (Windows Developer Mode). **Teruji: build Android TIDAK kena error symlink** — flutter tool mampu jalan sampai gradle; kegagalan build murni karena RAM 0.2GB (daemon gradle collapse + "Could not start thread"). Sekarang 13 plugin terpasang — build APK full belum diverifikasi karena RAM, diserahkan ke sesi `flutter run` user (dengan tips: tutup IDE/browser). Settings Developer Mode sudah dibuka buat user (toggle manual, butuh admin).
- **Command wajib diperbarui**: `flutter test --concurrency=1` (RAM), dan setelah injeksi store — test app butuh setMockInitialValues kalau nambah SharedPreferences lagi.
- Zona depan: Pengelolaan Media (Modul 12) — kamera/galeri/file, kemungkinan: foto hasil lab / profil pasien. Data sudah punya fondasi storage lokal; media tinggal nyambung.