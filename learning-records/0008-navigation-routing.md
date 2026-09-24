# Navigation & Routing — selesai (Modul 8)

Modul 8 selesai: teori dari materi dosen (navigation-routing.html) diterapkan dan app berubah dari satu halaman menjadi **multi-halaman**. Struktur dipecah ke `lib/screens/`. Tantangan dosen (Katalog Produk) diadaptasi jadi **Katalog Pasien**: daftar pasien di dashboard bisa diklik → DetailPasienPage (passing data via constructor: nama/umur/hb) → tombol "Catat ke Jadwal" melakukan `Navigator.pop(context, nama)` → dashboard `await` hasilnya dan tampilkan SnackBar (pola return data + async/await dari Modul 5). Ditambah: `HomeShell` StatefulWidget dengan `NavigationBar` 3 tab (Beranda/Jadwal/Info), `Drawer` dengan header "Halo, Silvi!", dan named route `/tentang`. `flutter test` 3 test pass (render dashboard, flow navigasi lengkap dengan SnackBar, drawer+named route), `flutter analyze` No issues.

## Implications
- **File splitting dimulai**: `lib/main.dart` (app + routes + shell + halaman kecil) vs `lib/screens/` (dashboard, detail, tentang). Ini fondasi struktur yang bakal dipakai sampai Modul 16 — modul berikutnya tinggal nambah file per fitur.
- Pemisahan jalur navigasi ditegaskan: **tab** (NavigationBar) mengganti konten shell vs **push** (Navigator) menumpuk halaman baru di atas segalanya. User sempat bingung "kenapa tab Jadwal nggak kesambung ke menu Jadwal" — ini beda konsep yang wajib jelas sebelum Modul 9.
- `context.mounted` setelah `await` dipakai sejak awal — kebiasaan yang menghindari bug "use_build_context_synchronously" di kode produksi.
- Test sekarang menguji **alur** (tap → pindah halaman → pop → SnackBar), bukan cuma render statis — pendahuluan natural ke Modul 13 (Testing).
- Data masih statis di dalam widget (`final List<Map> _pasien` di StatelessWidget) — batas ini akan pecah di Modul 9 (state management) dan Modul 10-11 (API/database). Zona perkembangan sudah terpetakan.
- Zona perkembangan berikutnya: State Management (Modul 9) — pindah data ke luar widget (setState lokal → state global: Provider/Riverpod/Bloc), bikin jadwal tab beneran nyimpen pasien yang dicatat.</think>

<｜DSML｜tool_calls>
<｜DSML｜invoke name="write">
<｜DSML｜parameter name="content" string="true"># Navigation & Routing — selesai (Modul 8)

Modul 8 selesai: teori dari materi dosen (navigation-routing.html) diterapkan dan app berubah dari satu halaman menjadi **multi-halaman**. Struktur dipecah ke `lib/screens/`. Tantangan dosen (Katalog Produk) diadaptasi jadi **Katalog Pasien**: daftar pasien di dashboard bisa diklik → DetailPasienPage (passing data via constructor: nama/umur/hb) → tombol "Catat ke Jadwal" melakukan `Navigator.pop(context, nama)` → dashboard `await` hasilnya dan tampilkan SnackBar (pola return data + async/await dari Modul 5). Ditambah: `HomeShell` StatefulWidget dengan `NavigationBar` 3 tab (Beranda/Jadwal/Info), `Drawer` dengan header "Halo, Silvi!", dan named route `/tentang`. `flutter test` 3 test pass (render dashboard, flow navigasi lengkap dengan SnackBar, drawer+named route), `flutter analyze` No issues.

## Implications
- **File splitting dimulai**: `lib/main.dart` (app + routes + shell + halaman kecil) vs `lib/screens/` (dashboard, detail, tentang). Ini fondasi struktur yang bakal dipakai sampai Modul 16 — modul berikutnya tinggal nambah file per fitur.
- Pemisahan jalur navigasi ditegaskan: **tab** (NavigationBar) mengganti konten shell vs **push** (Navigator) menumpuk halaman baru di atas segalanya. Ini beda konsep yang wajib jelas sebelum Modul 9.
- `context.mounted` setelah `await` dipakai sejak awal — kebiasaan yang menghindari bug "use_build_context_synchronously" di kode produksi.
- Test sekarang menguji **alur** (tap → pindah halaman → pop → SnackBar), bukan cuma render statis — pendahuluan natural ke Modul 13 (Testing).
- Data masih statis di dalam widget (`final List<Map> _pasien` di StatelessWidget) — batas ini akan pecah di Modul 9 (state management) dan Modul 10-11 (API/database).
- Zona perkembangan berikutnya: State Management (Modul 9) — pindah data keluar dari widget (setState lokal → state global), bikin tab Jadwal beneran nyimpen pasien yang dicatat.