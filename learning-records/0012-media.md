# Pengelolaan Media (Image, Audio, File) — selesai (Modul 12)

Modul 12 selesai: teori (media.html) diterapkan. **Stub "Input Lab" dari M7 diwujudkan** — tile menu itu sekarang membuka **Galeri Hasil Lab** beneran.

Hal yang dikerjakan:
1. **image_picker + path_provider** — ambil foto dari kamera/galeri (`imageQuality: 80`, `maxWidth: 1280`), copy dari cache sementara ke `<getApplicationDocumentsDirectory>/foto_<timestampMs>.jpg` biar persisten lintas restart.
2. **GaleriLabService** — pola DI yang sama kayak M10/M11: `getDir` injectable → produksi pakai direktori asli, widget test inject folder temp (path_provider = plugin native yang nggak ada di widget test).
3. **Tantangan dosen 1 & 2 diimplementasi**: long-press → AlertDialog "Hapus foto ini?" → `File.delete()` + reload + SnackBar hijau; overlay tanggal dari nama file (`tanggalDariNamaFile()` → label "24 Sep 2026, 14:30" di pojok thumbnail).
4. **Tantangan 3 & 4 di-skip jujur**: Audio Recorder (nggak ada kebutuhan record audio di app anemia) dan share_plus (ditunda ke final project — "share hasil lab ke dokter"). file_picker juga teori dulu (upload laporan PDF hasil lab = calon fitur M16).

Keputusan & pelajaran:
- **Deviasi permission dicatat**: READ_MEDIA_IMAGES aja yang masuk manifest. Dosen minta CAMERA + READ_EXTERNAL_STORAGE + READ_MEDIA_* lengkap, tapi `image_picker` di Android pakai intent sistem (Activity kamera / photo picker) → permission CAMERA/storage nggak wajib, malah "UnusedPermission" lint warning kalau dipasang tak terpakai.
- **Pelajaran terbesar: IO asli di widget test ≠ mock.** Kategori bug baru: operasi file nyata (baca gambar, dir.list, delete) nggak pernah "rampung" di zona FakeAsync widget test. Butuh: seeding **sync** (zone-proof), dan **alternasi `pumpAndSettle` ↔ `tester.runAsync`** berulang — tiap hop IO selesai di real time, kontinuasinya antri microtask FakeAsync yang cuma jalan pas pump. Helper `settleDenganIO()` di test galeri mengkodekan pola ini.
- **Windows file lock**: `Image.file` yang read-nya belum kelar bikin `File.delete()` kena `PathAccessException errno 32`. Solusi lapis: biarkan pipeline gambar kelar (runAsync alternating), `errorBuilder` di Image.file (foto korup → placeholder, bukan exception nyembur), dan teardown retry (scan Windows Defender).
- `errorBuilder: (_, __, ___)` → lint baru Dart minta `(_, _, _)` (wildcard berulang) — `unnecessary_underscores`.

Verifikasi: `flutter analyze` No issues; **18 test pass** (3 unit `galeri_service` + 3 widget galeri + 12 lama), `flutter test --concurrency=1`.

## Implications
- Dua tantangan dosen + error handling bikin galeri siap pakai harian; pola `settleDenganIO` bakal kepake lagi di modul testing (M13) dan di semua test yang sentuh file/plugin.
- Media + storage lokal (M11) + API (M10) = fondasi lengkap buat final project (M16): data pasien, foto hasil lab, dan jadwal pemantauan semuanya sekarang punya jalur persisten yang teruji.
- Zona depan: **Modul 13: Testing** — materi dosen testing.html; project kita sudah 18 test, jadi modul ini bakal ngerapiin/ngedalemin praktik testing (mungkin: group/describe, matchers, integration test/plugin test, coverage).