# Publish: GitHub Releases (adaptasi Play Store, Skenario C) — selesai (Modul 15)

Modul 15 selesai. Teori Play Store dari dosen dibaca penuh dan dirangkum di lesson; **eksekusi pilih Skenario C dosen (tanpa Play Store)** atas arahan user: **rilis lewat GitHub Releases** — berbarengan dengan kewajiban dosen "buat GitHub README berisi deskripsi + link download".

## Materi Play Store (dirangkum, belum dieksekusi)
Akun $25 sekali (personal; verifikasi identitas) → Create app (nama, id-ID, App, Free) → asset wajib (icon 512 tanpa alpha, feature graphic 1024×500, ≥2 screenshot/device) → main store listing (short ≤80, full ≤4000) → app content (privacy policy WAJIB, ads=No, access, content rating ESRB, target audience, data safety "No data collected") → closed testing (12 tester, 14 hari — kebijakan 2023+) → promote → staged rollout (10/50/100%) → update version via pubspec (1.0.0+1 → 1.1.0+2) → monitor (statistics, vitals, review). Penyebab ditolak: privacy policy mati, permission tak terpakai (CAMERA kita sengaja nggak dipasang — image_picker intent sistem), screenshot misleading, crash device bersih, claim resmi tanpa lisensi.

## Yang dieksekusi (Skenario C + wajib README)
1. **README.md** — deskripsi, tabel fitur per modul, link download, cara build, teknologi, struktur, disclaimer medis (bukan pengganti diagnosis).
2. **Persiapan kemas** — `.gitignore` + `**/android/**/debug.keystore`; verifikasi `git check-ignore` sebelum commit: `android/key.properties`, `android/app/upload-keystore.jks`, `build/`, `coverage/` semua ke-ignore (rahasia signing aman).
3. **git init -b main** → commit 219 file (`085e5d3`) — repo public **github.com/xzael24/anemia-care** → push main.
4. **Release v1.0.0** via `gh release create` dengan aset: `app-release.apk` (50.4MB), `app-arm64-v8a-release.apk` (17.8MB), `app-release.aab` (49.4MB), notes id-ID (release-notes.md). Live: https://github.com/xzael24/anemia-care/releases/tag/v1.0.0

## Jebakan nyata
- **`GITHUB_TOKEN` env invalid nge-block gh CLI** — `gh auth status` tampil dua kredensial: env token (invalid, "active") vs keyring xzael24 (valid, tapi kalah). Semua `gh`/`gh api` error 401 sampai `Remove-Item Env:GITHUB_TOKEN` dijalankan per sesi shell. Pelajaran: token env selalu override keyring — kalau gh error 401 tapi `gh auth status` bilang login, cek env dulu.
- PowerShell `gh api -q '<query>'` quoting gampang kepotong — untuk kebutuhan simpel, `gh release view` cukup.

## Tantangan dosen → status
| Skenario | Status |
|---|---|
| A: akun Play Console lengkap | 📝 teori — AAB + signing siap; butuh $25 + identitas + 12 tester 14 hari |
| B: asset submission-ready | 📝 sebagian — icon 512+ dari M14; screenshot & feature graphic butuh sesi `flutter run`/emulator |
| **C: tanpa Play Store** | ✅ GitHub Releases + direct APK + feedback via Issues |
| Wajib: GitHub README (screenshot, deskripsi, link) | ✅ deskripsi + fitur + link release; screenshot menyusul (sesi emulator) |

## Verifikasi
- Repo public live, 219 file, main branch, release v1.0.0 published (bukan draft/prerelease), 3 aset teratach, notes render.
- `flutter analyze` & 35 test tetap hijau (tidak ada perubahan kode Dart di modul ini).

## Implications
- **App bisa didistribusikan DEKAT**: siapa saja unduh APK dari Releases (17.8MB arm64 — ukuran wajar di-blast di grup/WA).
- **Riwayat tersimpan**: repo GitHub = portofolio + cadangan (sebelumnya bukan git repo sama sekali — sekarang aman!).
- Kalau nanti ingin Play Store: jalur M15-Skenario A sudah 80% siap (AAB, signing, keystore dibackup) — tinggal akun, listing, privacy policy (bisa gratis via GitHub Pages), dan 12 tester.
- Zona depan: **Modul 16: Final Project (final-project.html)** — ini modul penutup; kemungkinan besar integrasi semua fitur + polish + dokumentasi final. Ini juga kesempatan mendaratkan fitur pending: share hasil lab ke dokter (share_plus), upload laporan PDF (file_picker) — kalau mantap & RAM cukup.