# MANIFEST DATASET — Skrining Anemia via Foto Kuku

> Dokumen kendali semua data yang dipakai. Update status di sini setiap ada perubahan.
> Terakhir diupdate: 24 Sep 2026

---

## 1. Tujuan & Prinsip

- Dataset dipakai untuk melatih **2 pendekatan ML** yang dibandingkan: *feature-based* (R/(G+B), LAB a*, fitur kuku÷kulit) dan *CNN transfer learning* (MobileNetV2/EfficientNet).
- **Labeling mengacu cut-off WHO 2024** (lihat `docs/RINGKASAN_WHO_2024_Guideline_Hb.pdf`) — bukan 2011.
- Aturan emas: jangan mencampur data yang sebenarnya **sumber sama** (bikin data leak di split).
- Semua file yang masuk `data/raw/` dicatat MD5/ukuran → audit sebelum dipakai training.

---

## 2. Struktur Folder

```
data/
├── MANIFEST_DATASET.md      ← dokumen ini
├── raw/                     ← data mentah apa adanya (jangan diedit)
│   ├── figshare-nature-photo-hb/   ✅ Nature (Yakimov et al. 2024) — 250 pasien
│   ├── kaggle-ghana/                ✅ GHANA (mirror Mendeley) — 4.260 foto
│   ├── kaggle-ayushcl/              ✅ Fingernails (Apache 2.0) — 1.777 foto
│   ├── kaggle-udayranjan/           ✅ Pilot Manav Rachna (CC BY-SA 4.0) — 7.041 foto
│   └── ieee-dataport/               ⏳ IEEE 1.485 org — paywall (butuh subscription/membership)
├── processed/               ← hasil preprocessing (crop kuku, fitur, split) — ✅ SELESAI
│   ├── images/              ← 2.907 crop 224×224 (ghana asli, nature crop kuku, uday)
│   ├── rows.csv / dataset.csv / train.csv / val.csv / test.csv
│   └── {train,val,test}/images/   ← salinan per split, siap training
├── logs/                    ← log download/verifikasi
```

---

## 3. Sumber Dataset

### S1 — Nature / figshare: "Human skin and fingernails images for Hb assessment" ✅ SELESAI

| | |
|---|---|
| **Penulis / tahun** | Yakimov et al., 2024. DOI artikel: 10.1038/s41597-024-03895-9 |
| **Data DOI** | 10.6084/m9.figshare.25867432.v1 |
| **Link** | springernature.figshare.com/collections/6760179 |
| **Kode preprocessing** | github.com/biophotonics-msu/photo-haemoglobin |
| **Lokasi lokal** | `data/raw/figshare-nature-photo-hb/` |
| **File** | `data.zip` (91.619.743 byte) — MD5 `7bd86daf16c69e370173d9a7a92474b0` ✅ cocok |
| **Isi** | `metadata.csv` (250 baris) + `photo/` (251 jpg) |

**Hasil audit lokal:**
- 250 pasien unik, SEMUA punya bounding box kuku + kulit (3 jari/pasien).
- Hb 44–169 g/L, median 132 — sebaran bagus buat skrining.
- ⚠️ **Anomali: `photo/185.jpg` tidak punya baris metadata.** Keputusan: eksklusi dari training sampai diverifikasi (file orphan).
- ⚠️ **Tidak ada umur/jenis kelamin** (sengaja dianonimkan peneliti) → labeling per WHO butuh keputusan asumsi (lihat §4).

**Konvensi bounding box — SUDAH DIKONFIRMASI (24 Sep 2026):**
- Tiap bbox = **`[top, left, bottom, right]`** — BUKAN `[x1, y1, x2, y2]` (sumber: paper Data Records + kode resmi `biophotonics-msu/photo-haemoglobin`: `img[top:bot, left:right]`).
- **Tanpa rotasi/flip:** koordinat langsung berlaku di foto 800×600 apa adanya.
- Crop kulit pakai `SKIN_BOUNDING_BOXES` dengan konvensi sama.
- ⚠️ Fix 24 Sep 2026: pipeline sempat salah tafsir bbox sebagai `[x1,y1,x2,y2]` + rotasi → semua crop nature diregenerasi dengan parsing benar `(top,left,bottom,right)` → `crop(left, top, right, bottom)`. **Verifikasi visual: crop pid 1, 5, 6, 12, 100 = nail bed asli.**
- White reference (untuk normalisasi iluminasi versi feature-based, kalau dipakai): `skimage`/paper pakai kotak 50×50 di `[x=350..400, y=300..350]`

### S2 — Ghana: "Detection of Anemia using Colour of the Fingernails Image" ✅ SELESAI

> ⚠️ **TEMUAN PENTING (dedup):** Dataset "Ghana 4.260" di Kaggle (`kritagyadev/anemia-using-fingernails-image-datasets-from-ghana`) adalah **MIRROR dari Mendeley 10.17632/2xx4j3kjg2** — sumber yang sama, bukan dua dataset beda. **Jangan unduh dua-duanya → cegah data leak.**

| | |
|---|---|
| **DOI Mendeley** | 10.17632/2xx4j3kjg2.1 (Asare et al., 2022) |
| **Link** | data.mendeley.com/datasets/2xx4j3kjg2/1 |
| **Sumber unduhan** | Kaggle `kritagyadev/...` (downloadable via Kaggle API, 26,5 MB) |
| **Lokasi lokal** | `data/raw/kaggle-ghana/Fingernails/` |
| **Isi** | 710 foto asli (426 anemic / 284 non-anemic) → **di-augmentasi jadi 4.260** |
| **Populasi** | Anak **≤ 5 tahun**, foto oleh petugas lab, kamera ≥12MP, spotlight dimatikan |
| **Lisensi** | Mirror Kaggle "Unknown" — ⚠️ perlu cek lisensi asli Mendeley sebelum dipublikasikan |

**Hasil audit lokal (24 Sep 2026):**
- ✅ **4.260 file PNG**, label dikodekan di **nama file** (bukan folder).
- Distribusi label: **anemic 2.565** ("Anemic-FN-" 2.221 + "Anemic-Fin-" 300 + typo "Anmeic-fn-" 44) · **non-anemic 1.695** ("Non-Anrmic-" 1.581 + "Non-anemic-" 114). Rasio ±60/40 konsisten dgn rasio asli 426/284.
- ⚠️ **Filename penuh typo** ("Anmeic", "Anrmic") → parser label wajib hafal varian ini, jangan cuma cocokkan "Anemic".
- ⚠️ Flat folder, tanpa metadata CSV → tidak ada nilai Hb/usia per file (hanya label biner).

**Catatan labeling:** populasi anak ≤5 th → **cut-off WHO 2024 anak 6–23 bln (<105 g/L) & 24–59 bln (<110 g/L)** — tapi karena label aslinya hasil keputusan lab Ghana, kita pakai label bawaan "anemic/non-anemic" sebagaimana adanya.

### S3 — Kaggle: "Fingernails" / "anemia_fingernail" (ayushcl) ✅ SELESAI

| | |
|---|---|
| **Link** | kaggle.com/datasets/ayushcl/fingernails (10,8 MB, Apache 2.0) |
| **Lokasi lokal** | `data/raw/kaggle-ayushcl/Finger_Nails/` |
| **Isi** | Folder `Anemic/` (90 file) + `Non-Anemic/` (1.687 file) = **1.777 file** |
| **Lisensi** | Apache 2.0 ✅ — satu-satunya lisensi eksplisit aman |
| **Status** | Dataset pelengkap. ⚠️ **Sangat tidak seimbang** (5% anemic) → jangan dipakai tunggal, cukup nambah varian untuk non-anemic / uji generalisasi. |

### S4 — IEEE DataPort: "Non-Invasive Anemia Screening Using Conjunctiva, Palm and Nail bed Images" ⏳ PAYWALL

| | |
|---|---|
| **Link** | ieee-dataport.org/documents/dataset-non-invasive-anemia-screening-using-conjunctiva-palm-and-nail-bed-images-0 |
| **DOI** | 10.21227/n7km-nr64 |
| **Penulis** | R. Girija, M. Kaur, D. P. Sekhar (Manav Rachna, Faridabad, India) |
| **Isi** | **1.485 partisipan**, Hb lab 6,0–18,7 g/dL (166 anemic / 1.318 normal, WHO <12), modalitas: konjungtiva L/R, palmar L/R, ≤10 foto nail-bed/org, `Patient_Info.csv` |
| **File** | `Dataset.7z` (1.018,69 MB), format `.7z` |
| **Akses** | ⚠️ **Standard Dataset = WAJIB subscription** (individu $40/bln; **GRATIS utk IEEE Society Members**; kampus dgn institutional subscription juga bisa). Akun gratis TIDAK cukup. |
| **Catatan** | Dataset terbesar dgn Hb lab. Perlu salah satu jalur di §6 untuk mengunduh. |

### S5 — Pilot Manav Rachna (Kaggle: "Nail and conjuctival images for anemia detection") ✅ SELESAI

| | |
|---|---|
| **Link** | kaggle.com/datasets/udayranjankumar/nail-and-conjuctival-images-for-anemia-detection (56,5 MB) |
| **Lisensi** | CC BY-SA 4.0 ✅ |
| **Lokasi lokal** | `data/raw/kaggle-udayranjan/Dataset_sample/` |
| **Isi (audit 24 Sep 2026)** | 7.041 foto: `Nail_Anemic` 1.718 · `Nail_Non_Anemic` 1.755 · `Eye_Anemic` 1.786 · `Eye_Non_Anemic` 1.782 |
| **Keterangan** | Label biner di struktur folder. **TANPA nilai Hb & tanpa subset palm** → kemungkinan versi augmentasi/pilot dari studi grup yang sama (paper: "Iron Deficiency Anemia Detection … Comparative Study of Fingernails, Palm and Conjunctiva"). Dipakai sbg pelengkap (crop kuku + data eye sebagai ekstra). ⚠️ **BUKAN pengganti S4** (tidak bisa labeling WHO tanpa Hb). |

### ~~S5 — "Kaggle fingernail-anemia-detection (5.390 file)"~~ ⚠️ DITANGGUHKAN

- Angka "5.390 file" **gagal diverifikasi ulang** (cek 24 Sep 2026). Kandidat bernama sama (`abhinavgolla/fingernail-anemia-detection`, 79,8 MB) adalah **akun mirror bot dengan lisensi "Unknown" & rating rendah** — tidak direkomendasikan.
- Diputuskan: **hapus dari daftar resmi** sampai sumber asli + lisensinya terverifikasi.

---

## 4. Keputusan Labeling & Desain

1. **Cut-off = WHO 2024.** Ringkasan: `docs/RINGKASAN_WHO_2024_Guideline_Hb.pdf`. Rujukan file asli: `docs/WHO_2024_Guideline_Hb_Cutoffs.pdf`.
2. **S1 Nature tanpa umur/sex** → opsi labeling (pilih di rapat tim):
   - (a) ambang "devasa konservatif" **< 120 g/L** (ambang terendah grup dewasa = wanita) — prioritas recall anemia tinggi; atau
   - (b) buat dua label terpisah per ambang (120/130) dan latih dua varian; atau
   - (c) skip S1 dari labeling kategorik → pakai hanya untuk **regresi Hb / fitur relatif kuku÷kulit**.
   - Rekomendasi sementara: **(a)**, konsisten dgn prioritas sensitivitas. ⏳ konfirmasi tim.
3. **S2 Ghana anak ≤5 th** → cut-off anak WHO 2024 (6–23 bln / 24–59 bln). Usia tersedia di metadata Mendeley.
4. **Etnis/tone kulit = kalibrasi & preprocessing citra, BUKAN penyesuaian cut-off** (sesuai WHO 2024; sudah diputuskan).
5. **Split wajib per pasien** (patient-level), bukan per gambar — cegah bocor antar-jari pasien yang sama.

---

## 5. Status & Blocker

| Sumber | Ukuran | Status | Blocker |
|---|---|---|---|
| S1 Nature/figshare | 87 MB | ✅ 250 pasien, MD5 verified | — |
| S2 Ghana/Mendeley | 26,5 MB | ✅ 4.260 file teraudit | — |
| S3 ayushcl Fingernails | 10,8 MB | ✅ 1.777 file teraudit | — |
| S5 Pilot Manav Rachna | 56,5 MB | ✅ 7.041 file teraudit | — |
| S4 IEEE DataPort | ±1 GB | ⏳ | **Subscription/membership** (lihat §6) |

**Status preprocessing (24 Sep 2026):**
- ✅ **Dataset final: 2.907 gambar unik** (1.418 anemic / 1.489 non-anemic) dari 838 pasien (ghana 2.097/528 · nature 750/250 · udayranjan 60/60).
- ✅ Split per-pasien stratified seed 42: train 70,4% / val 14,7% / test 14,9%.
- ✅ Dedup md5 global: ayushcl dibuang (0 unik), udayranjan Eye_* off-scope, Nail_* tersisa 60 (semua non-anemic).
- ✅ Crop nature diperbaiki (konvensi `[top,left,bottom,right]`) + verifikasi visual.
- ✅ 1.934 gambar yatim (run lama sebelum dedup) dibersihkan dari `images/` — folder = persis 2.907 file CSV.
- ✅ **Artefak training siap**: `data/upload/anemia_nail_dataset_v1.zip` (23,8 MB, md5 `4af347f89e6926b1c7814d55254c83f7`) + notebook `scripts/training/baselines_colab.ipynb` (feature-based + CNN + regresi Hb).

**Sisa tindakan tim:**
1. ✅ Kaggle pakai format token `~/.kaggle/access_token` (beres, CLI jalan).
2. ✅ Preprocessing + split selesai & terverifikasi.
3. **S4 IEEE** — pilih salah satu jalur di §6, unduh `Dataset.7z` → taruh di `data/raw/ieee-dataport/` (menambah varian Hb lab; bukan blocker training).

## 6. Jalur Mendapatkan Dataset IEEE (S4) — urut dari paling murah

1. **IEEE Society Member di tim/dosen kalian** → login di ieee-dataport.org = otomatis punya Individual Subscription GRATIS (senilai $480/th) → bisa download semua Standard Dataset. Cek dulu: ada anggota IEEE di fakultas?
2. **Subscription institusi kampus** (library/fakultas) — beberapa kampus langganan IEEE DataPort → minta akses via pustakawan.
3. **Hubungi penulis langsung** (umumnya mau share utk riset): R. Girija / Manpreet Kaur / D. P. Sekhar — Manav Rachna University. Cari via ORCID atau ResearchGate (paper: "Iron Deficiency Anemia Detection … Comparative Study of Fingernails, Palm and Conjunctiva of the Eye Images").
4. **Pakai akun IEEE membership sendiri** kalau ada yang punya member number.
5. **Terakhir (berbayar):** subscription individu $40/bulan → download → cancel. (Pilihan "gue gamau tau"-nya tim; keputusan tim.)

---

## 6. Referensi

- Yakimov BP et al. *Dataset of human skin and fingernails images for non-invasive haemoglobin level assessment.* Sci Data 11, 2024. doi:10.1038/s41597-024-03895-9
- Asare JW et al. *Detection of Anemia using Colour of the Fingernails Image Datasets from Ghana.* Mendeley Data, V1, 2022. doi:10.17632/2xx4j3kjg2.1
- WHO. *Guideline on haemoglobin cutoffs to define anaemia in individuals and populations.* 2024.
- BKPK Kemenkes. *SKI 2023 Dalam Angka.* 2023. (`docs/SKI_2023_Dalam_Angka.pdf`)