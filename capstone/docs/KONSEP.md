# CAPSTONE — Konsep: Skrining Anemia Non-Invasif via Foto Kuku (Nail Bed Pallor)

> **Status:** Draft konsep (diskusi tim)
> **Tim:** Zaim, Hammam, Muzaki, Intan
> **Semester:** 5 (2026) — Gabungan mata kuliah semester 5
> **Tanggal:** 23 September 2026

---

## 1. Ringkasan Eksekutif

Sistem skrining anemia non-invasif berbasis foto kuku jari tangan. Pengguna memotret
kuku jarinya lewat aplikasi Android, sistem melakukan segmentasi & analisis warna
kuku (nail bed pallor), lalu memberi indikasi awal: *Normal*, *Indikasi Anemia
Ringan*, atau *Indikasi Anemia Berat* — dilengkapi rekomendasi tindak lanjut yang
dipersonalisasi (fuzzy logic).

Sistem menegaskan ini **alat skrining awal (indikasi), bukan pengganti diagnosis
medis** — hasil yang menunjukkan anemia akan direkomendasikan untuk pemeriksaan
darah (Hb) di fasilitas kesehatan.

Output sistem: **aplikasi Android (pengguna) + web (landing page & admin
monitoring untuk petugas kesehatan/kader)**, berbagi satu backend NestJS.

---

## 2. Konteks & Constraint (Locked)

| # | Constraint | Nilai |
|---|---|---|
| 1 | Wajib integrasi matakuliah semester 5 | Ya — ML, Pengolahan Citra Digital, Pemrograman Sistem Cerdas 1, Data Warehouse, Cloud, Pengujian Perangkat Lunak, Framework Programming, Mobile Programming |
| 2 | Backend | **Wajib NestJS** |
| 3 | Output | Web **dan** Android |
| 4 | Peran platform | Boleh berbeda: mobile = pengguna diskrining, web = petugas/admin |
| 5 | Timeline | ±3–4 bulan (1 semester) |
| 6 | Data | Dataset publik + data dummy + survei kebutuhan user |
| 7 | Bidang | Kesehatan |

---

## 3. Masalah & Target User

**Masalah:**
- Anemia umum terjadi (khususnya Indonesia: ibu hamil, remaja putri, anak-anak)
- Pengecekan anemia standarnya butuh tes darah (invasif, butuh fasilitas, biaya)
- Gejala awal anemia (lemas, pucat) sering diabaikan karena tidak terukur
- Dibutuhkan alat skrining awal yang murah, cepat, non-invasif

**Target user:**
- **Pengguna umum** (Android): siapa saja yang ingin cek indikasi awal anemia
- **Kader kesehatan / petugas puskesmas** (web): memantau hasil skrining,
  merekomendasikan pemeriksaan lanjutan, melihat tren di wilayahnya

**Narasi penggunaan realistis:** skrining di posyandu, acara donor darah,
ibu hamil, atau screening mandiri dari rumah.

---

## 4. Konsep Sistem & Alur Pengguna

### 4.1 Mobile — Alur Pengguna sampai Hasil Skrining

**Fase A — Pra-skrining**
1. **Landing/Onboarding** — intro singkat: apa itu skrining anemia non-invasif,
   disclaimer awal (*"bukan diagnosis medis"*), tombol mulai
2. **Daftar / Login** — akun wajib (hasil & riwayat tersimpan per akun)
3. **Halaman Utama (Home)** — tombol "Mulai Skrining", ringkasan hasil terakhir,
   shortcut info & edukasi

**Fase B — Proses Skrining (alur inti)**
```
Mulai Skrining
   ↓
[1] Persiapan & instruksi capture
   (kuku bersih tanpa inai/kuteks, dorong kutikula,
    tangan di permukaan datar, flash ON)
   ↓
[2] Capture foto kuku (jempol/telunjuk)
   ↓
[3] Gerbang Validasi Kualitas Citra ── gagal → pesan spesifik
   (lapisan / struktur / warna / zona sampel)      + foto ulang / ganti jari
   ↓ lolos
[4] Isi konteks singkat (input fuzzy logic):
   gejala (pusing/lemas/berkunang-kunang),
   menstruasi, kehamilan
   ↓
[5] Proses: preprocessing + model ML (loading + status)
   ↓
[6] HASIL SKRINING (detail di bawah)
   ↓
[7] Otomatis tersimpan ke rekam medis / riwayat
```

**Fase C — Layar Hasil Skrining (langkah 6)**
- Badge indikasi: 🟢 **Normal** / 🟡 **Indikasi Ringan** / 🔴 **Indikasi Berat**
- Confidence score (persentase keyakinan model)
- Disclaimer permanen: *"Hasil ini indikasi awal dari analisis citra, bukan
  diagnosis medis. Jika ada indikasi anemia, lakukan pemeriksaan darah (Hb)
  di fasilitas kesehatan."*
- **Rekomendasi personal** (output fuzzy logic):
  - Normal → tetap pola makan sehat & skrining berkala
  - Indikasi ringan → tingkatkan asupan zat besi + cek darah disarankan
  - Indikasi berat / menstruasi / hamil → segera periksa ke puskesmas/dokter
- Aksi: skrining ulang · lihat riwayat · info tindak lanjut

**Fase D — Setelah hasil**
- Riwayat skrining (daftar hasil + status verifikasi petugas)
- Monitoring berkala: tren indikasi dari waktu ke waktu (grafik)
- Notifikasi saat hasil diverifikasi petugas web

### 4.2 Web — Scope Awal: Landing Page + Admin Monitoring

Web tidak dibuat penuh; lingkup awalnya dua hal:

**1. Landing Page (publik, tanpa login)**
- Hero: nama & tagline aplikasi, cara kerja (3 langkah: foto → analisis → hasil)
- Keunggulan skrining non-invasif
- CTA download Android + link mulai
- Section edukasi anemia & disclaimer medis
- Kontak / tentang tim

**2. Admin Monitoring (login petugas kesehatan/kader) — dibangun di atas Data Warehouse**
- Dashboard monitoring kondisi skrining di wilayahnya
- Detail lengkap di bagian **Dashboard Admin Monitoring (Data Warehouse)**

---

## 5. Dasar Medis (kejujuran ilmiah)

- Nail bed pallor adalah tanda klinis sah yang dipakai WHO (IMCI) untuk skrining anemia
- Meta-analisis: specificity nailbed bisa tinggi (88–90% pada anemia berat);
  sensitivity sedang (29–80% tergantung ambang Hb) — jadi **lebih baik untuk
  "menandai" orang yang perlu cek darah daripada menegakkan diagnosis**
- ⚠️ Sinyal warna kuku **lemah untuk anemia ringan** (perbedaan warna kecil; studi
  spektrofotometer 2025 menunjukkan ΔE < 6 untuk rentang Hb 10–14, sulit dibedakan
  bahkan oleh mata terlatih)
- ⚠️ Akurasi alat foto ±10–15 g/L → **tidak boleh menjanjikan estimasi Hb presisi**

**Konsekuensi desain (wajib):**
- Output diframing sebagai **"indikasi awal"** + rekomendasi cek laboratorium
- Prioritaskan **sensitivitas** (jangan sampai anemia terlewat) — recall tinggi
  untuk kelas anemia, lalu optimize specificity
- Disclaimer eksplisit di UI: *"Ini bukan diagnosis medis"*

---

## 6. Arsitektur Teknis (Draft)

```
┌─────────────────────┐      ┌──────────────────────────────┐
│  Mobile (Android)   │      │  Backend NestJS               │
│  - capture + validasi│ ───▶ │  - auth, rekam medis          │
│  - hasil & riwayat  │  API  │  - orkestrasi deteksi         │
└─────────────────────┘      │  - integrasi ML & DW          │
                             └──────┬───────────────┬────────┘
┌─────────────────────┐             │               │
│  Web (petugas)      │ ◀───────────┘               │
│  - dashboard        │                             ▼
│  - verifikasi       │                  ┌───────────────────────┐
│  - analisis DW      │                  │ ML Service (Python)   │
└─────────────────────┘                  │ FastAPI: pipeline     │
                                         │ preprocessing + model │
                                         └───────────────────────┘
                                         ┌───────────────────────┐
                                         │ Data Warehouse (DW)   │
                                         │ ETL → star schema →   │
                                         │ dashboard analisis    │
                                         └───────────────────────┘
```

**Opsi deployment ML:**
- Opsi 1 (rekomendasi awal): service Python terpisah (FastAPI), backend NestJS panggil via HTTP
- Opsi 2: export model ke ONNX → inferensi langsung di NestJS (satu bahasa, tanpa service Python)

**Hosting:** cloud (misal Render/Railway/AWS) — poin matakuliah Komputasi & Aplikasi Cloud.

---

## 7. Pipeline Machine Learning

```
Foto kuku (mobile)
      ↓
[PCD] Segmentasi kuku ✅ ->  terintegrasi ke serving (/predict-hand, top-2/peak)
      ↓
[PCD] Normalisasi pencahayaan (CLAHE / Retinex) ⬜ ->  roadmap, belum
      ↓
[PCD] Ekstraksi fitur warna (R/(G+B); koordinat a* di CIELAB) ✅ (33D, RandomForest)
      ↓
[ML]  Model: klasifikasi (Normal / Indikasi Ringan / Indikasi Berat)
      ↓
Hasil + confidence score → rekam medis (NestJS)
      ↓
[PSC1] Fuzzy Logic: gabung hasil visual + profil user → rekomendasi personal
```

### 7.0 Status implementasi terukur (2026-09-25)

Angka jujur (detail lengkap: `ml_service/README.md` di repo apply; dataset
figshare Nature 250 foto tangan penuh, evaluasi pada set tes penuh = ceiling
empiris, bukan hold-out):

| Komponen | Hasil terukur | Ambang target |
|---|---|---|
| PCD recall@0.5 (vs GT box) | **0.657** (493/750), IoU matched 0.594 | ~0.5 (localizer) |
| Rantai otomatis PCD→crop→RF (AUC) | **0.794** (GT-oracle 0.879; RAW 0.415) | evaluasi e2e |
| Operating point tangan penuh | t=0.25 → sens 0.855 · spec 0.503 | recall ≥ 0.85 |
| Serving close-up (domain training) | sens 0.877 · spec 0.614 (test) | recall ≥ 0.85 ✅ |

Batas jujur: precision PCD rendah (0.053 — kuku skin-colored nyaris tak
terdiskriminasi oleh skor HSV), sisa gap PCD→GT (0.794 vs 0.879) ditentukan
kualitas lokalisasi (IoU 0.594), bukan jumlah crop. Integrasi produk: endpoint
`POST /predict-hand` (multipart `file`) di sidecar ML + mode foto "Tangan penuh"
di app (kamera live + bingkai panduan kuku); threshold khusus `0.25`. QC lapis
pertama (deteksi keburaman, tolak 400) aktif di kedua endpoint; lampu kilat
default **AKTIF** di mode foto kuku (dokumen arsitektur: "lampu kilat aktif").

### 7.1 Preprocessing
- **Segmentasi:** konversi RGB→HSV, deteksi kontur (kulit vs kuku), fitting ellipse;
  dataset Nature menyediakan bounding box kuku untuk validasi
- **Normalisasi:** CLAHE / Retinex agar konsisten lintas pencahayaan & perangkat
- **ROI Sampling Strategy (penting):**
  - Ambil sampel dari **zona tengah-distal** plate dengan buffer aman
  - Skip area dekat kutikula (±15–20% panjang plate) — kontaminasi kulit
  - Skip **lunula** (bulan putih di pangkal — putih alami)
  - Skip tepi distal (bayangan ujung jari)
  - Gunakan **median** warna (bukan rata-rata) untuk anti-outlier
- **Ekstraksi fitur:** rasio `R/(G+B)`, koordinat `a*` CIELAB, fitur relatif
  (warna kuku ÷ warna kulit jari sendiri — normalisasi internal/by skin tone)

### 7.2 Pendekatan Model — DUA-DUA-NYA (nilai jual laporan)
| | A. Feature-based (RF/K-NN/SVM) | B. CNN Transfer Learning |
|---|---|---|
| Input | Fitur warna manual | Foto kuku langsung |
| Pro | Simpel, cepat, interpretable, jalan di laptop | Akurasi lebih tinggi, fitur otomatis |
| Kontra | Tergantung fitur manual | Butuh GPU/data lebih, black box |

- A = **baseline murah** (bisa dikejar di minggu 2 sebagai bukti konsep)
- B = model utama: **MobileNetV2 / EfficientNet** (pretrained ImageNet, fine-tune);
  versi kecil gampang di-deploy (ONNX)
- Laporan: bab *"Perbandingan Metode: Fitur Warna + Ensemble vs CNN"*

### 7.3 Target & Kelas
- **Klasifikasi 3 kelas (rekomendasi):** Normal (Hb ≥ 12) / Indikasi Ringan (8–12) /
  Indikasi Berat (< 8) — dibangun dari dataset yang punya nilai Hb lab
- Binary (Normal vs Indikasi Anemia) sebagai model utama paling realistis;
  3-kelas sebagai pengembangan
- ⚠️ Class imbalance (data berat sedikit di IEEE: 166/1.485) → metrik
  precision/recall (bukan accuracy doang), bobot kelas di training

### 7.4 Evaluasi
- Split 70/15/15 **per orang** (jangan per foto — hindari kebocoran data)
- Metrik: confusion matrix, precision, recall, F1, AUC
- **Cross-dataset validation (nilai plus):** train di dataset A → test di dataset B
- Framing screening: **recall/sensitivitas anemia diprioritaskan** (jangan ada
  anemia terlewat), specificity menyusul

---

## 8. Modul Validasi Kualitas Citra (Gerbang Input)

Semua edge case input-an diselesaikan oleh **satu modul terpusat** — memastikan
hanya citra valid yang masuk ke model ML.

### Cek yang dijalankan setelah capture:
| # | Cek | Deteksi | Tindakan |
|---|---|---|---|
| 1 | Ketajaman ✅ aktif (2026-09-25) | Laplacian Variance < 40 @480px (`BLUR_THRESHOLD`) | Tolak 400 + minta ulang (fokus tajam, cahaya cukup) |
| 2 | Lapisan | Inai, kutek, kutek bening, kerudung warna | Tolak + instruksi bersihkan/ganti jari |
| 3 | Struktur | Kuku retak, sobek, gigitan, ngelupas (plate area < ambang) | Tolak + saran jari lain |
| 4 | Warna abnormal | Hematoma (bekas kecepit), jamur (kekuningan) | Tolak |
| 5 | Zona sampel cukup | Kutikula tebal menutupi zona aman | Tolak + dorong kutikula / ganti jari |

### Layering-nya:
- **UI:** instruksi & konfirmasi sebelum foto ("pastikan kuku bersih tanpa inai/kutek")
- **PCD:** auto-detect lapisan (distribusi hue di plate), struktur (area/kontur),
  warna abnormal — *classifier mini "kuku valid vs tidak"*
- **UX:** pesan perbaikan spesifik + opsi pilih jari lain

### Catatan laporan:
Dataset Nature eksplisit hanya memakai **kuku tanpa lapisan buatan/kerusakan**
→ "kebersihan & keutuhan kuku" adalah kriteria kelayakan yang sah di metodologi.
Statistik penolakan (kenapa & berapa banyak) → masuk dashboard Data Warehouse
untuk evaluasi sistem.

---

## 9. Penanganan Variasi Warna Kulit (Skin Tone)

**Fakta:** nail bed relatif "melanin-free" (disebut di paper Nature 2024) — alasan
mengapa kuku dipilih untuk skrining Hb. TAPI pigmen tetap ada (melanonychia) pada
kulit lebih gelap, dan studi di berbagai negara menunjukkan variasi akurasi pallor
antar populasi.

**Solusi 4 lapis:**
1. **Multi-warna kulit di dataset:** India (IEEE) + Ghana (Kaggle) + Rusia (Nature)
   → model belajar "pucat relatif" bukan "warna absolut"
2. **Fitur relatif:** indeks pucat = warna nail bed ÷ warna kulit jari orang yang
   sama (self-normalization)
3. **Segmentasi anti-melanonychia:** deteksi & exclude garis/guratan gelap di plate;
   sampel warna dari zona bersih (median)
4. **Tipe kulit jadi fitur:** Fitzpatrick 1–6 ditanyakan saat profil → masuk ke model
   & fuzzy logic sebagai konteks kalibrasi

**Bonus laporan:** sub-analisis akurasi per kelompok tipe kulit (analisis bias) —
bahan diskusi yang jarang dimiliki capstone lain.

---

## 10. Dataset (Verified — 23 Sep 2026)

| Dataset | Isi | Link |
|---|---|---|
| **IEEE DataPort 2023** (⭐ utama) | 1.485 peserta, Hb lab (6.0–18.7 g/dL), foto nail bed + konjungtiva + telapak, metadata | https://ieee-dataport.org/documents/dataset-non-invasive-anemia-screening-using-conjunctiva-palm-and-nail-bed-images-0 |
| **Nature Scientific Data 2024** | 250 pasien, Hb resmi, bounding box kuku+kulit, kode preprocessing open-source | Dataset: https://springernature.figshare.com/collections/Dataset_of_human_skin_and_fingernails_images_for_non-invasive_haemoglobin_level_assessment/6760179 · Paper: https://www.nature.com/articles/s41597-024-03895-9 · Code: https://github.com/biophotonics-msu/photo-haemoglobin |
| **Kaggle — fingernail-anemia-detection** | 5.390 foto (Anemic/NonAnemic) | https://www.kaggle.com/datasets/abhinavgolla/fingernail-anemia-detection |
| **Kaggle — Ghana** | 4.260 foto (Ghana, anak-anak, kulit gelap dominan) | https://www.kaggle.com/datasets/kritagyadev/anemia-using-fingernails-image-datasets-from-ghana |
| **Mendeley — Ghana 2022** | 710 → augmentasi 4.260, pencahayaan terkontrol, ROI terpotong | https://doi.org/10.17632/2xx4j3kjg2 |

**Strategi:** IEEE atau Nature untuk training utama (ada Hb benar); dataset Ghana
untuk testing/cross-dataset (kondisi & populasi berbeda) → memperkuat bab
metodologi dan generalisasi.

---

## 10.1 Empat Lapisan Data di Sistem

```
LAPISAN 1: Dataset training (publik) — build & evaluasi model (offline)
   IEEE / Nature / Kaggle / Ghana
        ↓ (model jadi; dataset TIDAK dibawa ke app)
LAPISAN 2: Data operasional — hasil pakai app beneran
   user foto kuku → validasi → ML → hasil + confidence + profil
   → tersimpan di DB operasional (PostgreSQL)
        ↓ ETL
LAPISAN 3: Data Warehouse → dashboard admin monitoring
   (tren bulanan, % anemia, demografi, dst.)
LAPISAN 4: Data demo/seed — khusus capstone (user masih sedikit)
   generate record realistis biar dashboard hidup dari hari pertama
```

Catatan kunci: **aplikasi tidak "mengonsumsi" dataset publik saat berjalan** —
dataset publik hanya untuk melatih model. Setelah model jadi, app menghasilkan
datanya sendiri (foto + hasil) yang mengalir ke DB → DW → dashboard.

## 10.2 Detail Persiapan Dataset Training

### a. Pemilihan & pembersihan (cleaning)
- Dataset **utama (train/val):** IEEE DataPort (1.485 peserta, ada Hb lab) atau
  Nature (250, ada bbox) — karena punya label Hb benar
- Dataset **testing/generalisasi:** Kaggle Ghana (4.260, populasi & kondisi beda)
- Hanya foto yang memenuhi kriteria kelayakan: kuku terlihat jelas, tanpa lapisan
  (inai/kuteks) & tanpa kerusakan — dataset Nature sudah eksplisit memfilter ini
- Rapikan metadata: ID pasien unik (dasar split **per orang**), konsistensi label
- Dedupe: cek foto duplikat/identik antar file

### b. Labeling (definisi kelas)
- **Binary (model utama):** Anemia (Hb < 12 g/dL) vs Normal (Hb ≥ 12 g/dL) — ambang WHO
- **3 kelas (pengembangan):** Normal (≥12) / Indikasi Ringan (8–12) / Indikasi Berat (<8)
- Perhatikan penyesuaian ambang WHO per gender/usia (anak, pria, ibu hamil)

### c. Split yang benar (anti data leak)
- Split **per ORANG (subject-wise)**, bukan per foto — foto orang yang sama tidak
  boleh tersebar di train & test (bocor → akurasi palsu)
- Rasio 70/15/15 (train/val/test) dengan stratifikasi kelas & demografi
- Simpan daftar ID per split sebagai CSV (di-commit) → **reproducibility** (dipakai
  lagi kapan pun, hasil evaluasi bisa dibandingkan antar percobaan)

### d. Class imbalance
- IEEE: 166 anemic vs 1.318 non-anemic → sangat tidak seimbang
- Mitigasi: `class_weight` pada loss, metrik recall/precision/F1 (bukan accuracy
  doang), augmentasi/oversampling untuk kelas minoritas

### e. Augmentasi (kunci khusus kasus ini)
Karena sinyalnya **warna**, prioritas tertinggi:
- **Color jitter:** brightness, contrast, hue shift, white-balance shift →
  mensimulasikan beda HP & pencahayaan (ini yang membuat model tidak overfit ke
  kamera dataset)
- Standar lainnya: flip horizontal, rotasi kecil, zoom crop (kuku tetap objek
  utama), noise & blur ringan
- ⚠️ Jangan augmentasi ekstrem sampai mengubah realitas klinis (mis. kuku semua
  jadi kebiruan — itu data palsu)

### f. Pipeline preprocessing (urutan)
1. Crop/kirim ROI kuku → resize sesuai input model (mis. 224×224 MobileNet)
2. Normalisasi pencahayaan: CLAHE / Retinex
3. Zona sampling aman: skip kutikula-lunula-tepi distal → median warna
4. **Jalur feature-based:** ekstraksi fitur (R/(G+B), LAB a*, fitur relatif
   kuku÷kulit) → Random Forest / K-NN / SVM
5. **Jalur CNN:** ROI crop langsung → MobileNetV2/EfficientNet (fine-tune)

### g. Strategi evaluasi & generalisasi
- Baseline train/val/test pada dataset utama → metrik core (confusion matrix,
  precision, recall, F1, AUC)
- **Cross-dataset:** train di IEEE → test di Ghana (beda populasi/kondisi) →
  mengukur seberapa general model
- Sub-analisis akurasi per kelompok tipe kulit (jika metadata tersedia) → analisis bias
- (Opsional) uji regresi Hb sebagai pembanding, jika memungkinkan

### h. EDA — deliverable minggu 1–2
- Tabel statistik per dataset: jumlah foto, jumlah orang unik, distribusi kelas,
  ukuran piksel, metadata yang tersedia
- Contact sheet sampel foto (normal vs anemia) → bahan diskusi & lampiran laporan
- Cek bounding box (Nature) vs segmentasi otomatis ✅ (PCD recall@0.5 0.657, IoU 0.594 — lihat 7.0)

### i. Penyimpanan & lisensi
- `data/raw/` = dataset mentah (jangan di-commit git — besar); `data/processed/` =
  CSV split, statistik, augmentasi config (di-commit)
- `.gitignore` untuk `data/raw/`; dokumentasikan versi dataset + hash file
- Lisensi wajib dicatat & disitasi di laporan: IEEE DataPort (izin akses),
  Kaggle (per-dataset license), figshare Nature (CC-BY — cite), Mendeley
- Etika: isi foto pasien/anak → khusus riset/kuliah, jangan disebar

## 10.3 Data Operasional (dari Aplikasi)

Field utama per record skrining: `id_skrining`, `id_user`, `foto` (path/URL),
`kelas_hasil_ml`, `confidence_score`, `status_verifikasi`, `konteks` (gejala/
menstruasi/kehamilan), `tipe_kulit`, `waktu`, `device`. Data ini sumber
verifikasi petugas di web + bahan ETL ke DW.

## 10.4 Data Demo / Seed (khusus capstone)

- **Seed script / synthetic data generator:** ribuan record skrining realistis —
  profil konsisten, distribusi hasil wajar (mis. 75% normal, 20% ringan, 5%
  berat), tanggal tersebar antar bulan → dashboard hidup dari hari pertama
- **Dogfooding + user testing:** tim & teman pakai app beneran → data asli
  numpuk (foto kuku tim bisa jadi uji validasi data nyata)
- **Uji coba terarah:** skrining di posyandu/kampus → data + feedback asli
  (sekaligus data survei)

## 10.5 Privasi & Etika (nilai plus laporan)

- Data operasional = rekam medis → sensitif
- Consent pengguna saat mendaftar; DW dianonimasi (tanpa identitas, hanya demografi)
- Kebijakan retensi/hapus data; audit trail
- Catat kebijakan privasi ini di laporan — kelompok lain jarang menyentuh

---

## 11. Fuzzy Logic (Pemrograman Sistem Cerdas 1)

Menggabungkan hasil visual ML dengan konteks pengguna untuk rekomendasi personal:

**Input fuzzy:** hasil visual (rendah/sedang/tinggi) · menstruasi · kehamilan ·
gejala (pusing, lemas) · tipe kulit

**Contoh rule (Mamdani):**
```
IF visual = PUCAT AND user = HAMIL AND gejala = PUSING
    THEN resiko = TINGGI  → "Segera periksa ke puskesmas/dokter"

IF visual = NORMAL AND gejala = TIDAK ADA
    THEN resiko = RENDAH  → "Tetap pola makan sehat & cek rutin"

IF visual = SEDANG AND user = MENSTRUASI
    THEN resiko = SEDANG  → "Tingkatkan asupan zat besi (bayam, daging merah) + cek darah"
```

Output: rekomendasi tindak lanjut (pola makan, tablet tambah darah, atau rujukan).

---

## 12. Dashboard Admin Monitoring (Data Warehouse)

### 12.1 Apa itu "Admin Monitoring" di sini?

Bukan CRUD biasa — ini **dashboard monitoring berbasis Data Warehouse (DW)**:
petugas/kader memantau **kondisi kesehatan populasi terskrining** lewat agregasi
data, bukan hanya melihat data per pasien.

Contoh pertanyaan yang dijawab dashboard:
- "Berapa skrining bulan ini, dan berapa % yang mengarah anemia?"
- "Apakah tren indikasi anemia naik/turun tiap bulan?"
- "Kelompok usia/gender/tipe kulit mana yang paling banyak indikasi anemia?"
- "Di wilayah mana paling banyak indikasi berat?"
- "Berapa foto ditolak gerbang validasi & kenapa?" (evaluasi sistem)

### 12.2 Komponen Dashboard
- **KPI cards:** total skrining (periode ini), % indikasi anemia, jumlah pasien
  baru, jumlah penolakan citra
- **Tren bulanan:** line/area chart jumlah skrining & persentase anemia per bulan
- **Distribusi hasil:** donut Normal / Indikasi Ringan / Indikasi Berat
- **Demografi:** bar chart skrining per kelompok usia, gender, tipe kulit
- **Wilayah:** (jika ada data lokasi) perbandingan antar wilayah
- **Tabel skrining terbaru:** hasil, confidence, status verifikasi — ada filter
  (rentang tanggal, hasil, wilayah)
- Filter global + drill-down sederhana

### 12.3 Sumber Data & Alur DW
```
DB Operasional (PostgreSQL — data transaksi skrining)
      ↓ ETL (extract, transform, load)
Staging area
      ↓
Star Schema
   fact_skrining (measures: count, confidence)
   dim_waktu   (tanggal → bulan → tahun)
   dim_pasien  (usia, gender, tipe kulit, status hamil/riwayat)
   dim_hasil   (kelas hasil, status verifikasi)
   dim_lokasi  (wilayah)
      ↓ query agregat
Dashboard Admin (chart: Chart.js / Recharts / ECharts, atau BI tool: Metabase)
```
- ETL: script terjadwal (mis. cron/job harian) dari DB operasional → star schema
- Query agregat di-serve backend NestJS (API dashboard) → frontend web render chart
- Opsi alternatif: BI tool (Metabase / Looker Studio) langsung ke DW — keputusan TBD

### 12.4 Pembeda DW vs Rekam Medis Operasional
| | DB Operasional | Data Warehouse |
|---|---|---|
| Fokus | Transaksi: 1 skrining = 1 record pasien | Analisis: agregasi ribuan skrining |
| Bentuk | Normalized, update sering | Star schema, append/periodik |
| Pemakai | App mobile & verifikasi petugas | Dashboard admin monitoring |
| Contoh | "Riwayat pasien X" | "Tren anemia per bulan di wilayah Y" |

---

## 13. Pemetaan Mata Kuliah Semester 5

| Mata Kuliah | Peran di Capstone |
|---|---|
| Pengolahan Citra Digital | Segmentasi kuku, normalisasi (CLAHE/Retinex), ekstraksi fitur warna, modul validasi citra |
| Machine Learning | Model klasifikasi (RF/KNN baseline + CNN transfer learning), evaluasi metrik |
| Pemrograman Sistem Cerdas 1 | Fuzzy logic / forward chaining untuk rekomendasi personal |
| Framework Programming | Backend NestJS, REST API, orkestrasi |
| Mobile Programming | Aplikasi Android (capture, validasi, hasil, riwayat) |
| Data Warehouse | ETL → star schema → dashboard analisis tren skrining |
| Komputasi & Aplikasi Cloud | Deployment backend + ML service + database di cloud |
| Pengujian Perangkat Lunak | Unit/integration/E2E testing seluruh sistem |
| Leadership | Manajemen tim, pembagian tugas, komunikasi |

---

## 14. Pembagian Peran Tim (Draft)

| Role | Tanggung jawab | Matkul terkait |
|---|---|---|
| Backend (NestJS) | Auth, rekam medis, API deteksi, integrasi ML | Framework Programming |
| Mobile (Android) | UI user: capture, validasi, hasil, riwayat, monitoring | Mobile Programming |
| ML & PCD | Preprocessing kuku, model klasifikasi, evaluasi | ML, PCD |
| Web + DW | Landing page publik; dashboard admin monitoring (DW), verifikasi, ETL → DW | DW, Cloud |

Sisa tugas (testing, cloud, laporan) dibagi lintas-role. **Belum ada penetapan
siapa pegang role apa** — ditentukan minggu pertama berdasarkan minat & kemampuan
(catatan: anggota yang mau coba Python → ML/PCD).

---

## 15. Timeline (3–4 Bulan)

| Fase | Minggu | Isi |
|---|---|---|
| **0. Landasan** | 1–2 | Lock konsep & role, riset literatur, eksplorasi dataset, survei kebutuhan, setup repo, konsul dosen |
| **1. Foundation** | 2–4 | Skeleton NestJS, **ML baseline pertama** (fitur warna + RF — bukti konsep), uji preprocessing di sampel dataset |
| **2. Development** | 4–10 | Fitur paralel per role, model CNN, integrasi ujung-ke-ujung (foto → hasil), gerbang validasi, DW |
| **3. Polish** | 10–14 | Testing menyeluruh, deploy cloud, dashboard analisis, penulisan laporan bab 1–5 |

**Minggu 1 checklist:**
- [ ] Lock konsep + role tiap anggota
- [ ] Setiap anggota baca ≥1 jurnal anemia-from-nail (Nature 2024, Ghana) → ringkasan 1 paragraf
- [ ] Download & eksplorasi dataset (jumlah, kelas, ukuran, metadata)
- [ ] 1 halaman konsep → bahan konsul dosen
- [ ] Setup repo GitHub: `docs/`, `ml/`, `backend/`, `mobile/`, `web/`, `data/`

**Minggu 2 checklist:**
- [ ] Preprocessing sederhana + baseline Random Forest → akurasi awal (uji "kerasnya" data)
- [ ] Desain survei (Google Form, ±50 responden) → data Bab 1
- [ ] Konsul dosen: konsep + hasil baseline

---

## 16. Keputusan Terbuka (TBD)

- [ ] Jenis objek lain (konjungtiva/telapak) sebagai fallback/alternatif? (opsi masa depan)
- [ ] Kelas akhir: binary vs 3 kelas (diputuskan setelah baseline)
- [ ] Model final: RF/KNN vs CNN vs ensemble
- [ ] Deployment ML: service Python vs ONNX di NestJS
- [ ] Nama aplikasi & judul resmi capstone
- [ ] Penetapan role per anggota
- [ ] Tool dashboard DW: chart custom (Chart.js/ECharts) vs BI tool (Metabase/Looker Studio)
- [ ] Star schema final & frekuensi ETL (harian/mingguan)
- [ ] Scope verifikasi per-skrining di web (human-in-the-loop) — tahap awal atau lanjutan?
- [ ] Hasil eksplorasi dataset & survei (akan mengupdate keputusan di atas)

---

## 17. Referensi Awal

- Yakimov et al. — *Dataset of human skin and fingernails images for non-invasive
  haemoglobin level assessment*, Scientific Data (2024). doi:10.1038/s41597-024-03895-9
- Dataset Anemia (Nail) IEEE DataPort — 1.485 peserta, India (2023)
- Mannino et al. (2018) — estimasi Hb dari foto kuku via smartphone (error ±10–15 g/L)
- Meta-analisis pallor pada anemia anak — Chalco et al., BMC Pediatrics (2005)
- Kalantri et al. — akurasi pallor untuk deteksi anemia, PLoS ONE (2009)
- Studi 2025 — korelasi warna kuku/lip/konjungtiva vs Hb (spectrophotometer, L*a*b*)

---

## 18. Deviasi terukur vs "Dokumen Arsitektur Sistem & Alur Kerja" (2026-09-25)

Perbandingan jujur dokumen arsitektur vs implementasi saat ini — mana yang
diadopsi, mana yang dideviasi beserta alasan teknis (biar laporan tidak
menganggap "lupa"):

| Komponen dokumen | Status implementasi | Catatan |
|---|---|---|
| Skrining awal (bukan diagnosis) + disclaimer | ✅ diadopsi | Permanen di backend + app |
| Panduan bingkai kamera | ✅ diadopsi | Overlay bingkai kuku/tangan di kamera live |
| **Lampu kilat aktif saat foto** | ✅ diadopsi 2026-09-25 | Default `FlashMode.always` mode kuku, `auto` mode tangan + toggle |
| **QC ketajaman (Laplacian) → tolak & minta ulang** | ✅ diadopsi 2026-09-25 | Tolak 400; kalibrasi figshare (lihat seksi 8) |
| Profil usia & jenis kelamin | ✅ diadopsi | Akun pasien + tipe kulit/hamil/riwayat |
| Berat badan di profil | ❌ deviasi | Tidak relevan untuk skrining warna kuku; tidak dipakai fitur manapun |
| GPS / koreksi elevasi (WHO 2011) | ❌ deviasi | Izin lokasi + API eksternal tanpa gain terukur: pipeline binary dipakai cut-off flat; koreksi hanya signifikan >1000 mdpl. Opsi ringan (dropdown kota + elevasi statis) = TBD |
| Kuesioner klinis | ⚠️ sebagian | Form gejala/risiko/tipe kulit → masukan fuzzy, bukan 3-toggle CF |
| Gray-World + CLAHE L\* | ❌ roadmap | Normalisasi pencahayaan tetap bernilai untuk domain baru |
| Central ROI 40–50% skip kutikula/lunula | ⚠️ sebagian | Kotak crop high-DPI + fitur 33D (LAB + R-ratio hadir); detail ROI sampling = roadmap |
| Random Forest | ✅ (beda jenis) | RF **classifier** (label + prob), bukan regressor |
| Regresi Hb (Hb_visual, MAE/RMSE/R²) | ❌ deviasi terukur | Mannino ±10–15 g/L terlalu lebar untuk dipakai klinis; tetap roadmap sebagai pendukung, bukan output utama |
| Fusi CF Kalantri `CF_final` | ⚠️ beda mekanisme | Diganti **fuzzy Mamdani 12 rule** (PSC1): skor visual + gejala + risiko → rekomendasi; lebih kaya & dievaluasi |
| Ambang klaster Kemenkes 2023 (per siklus hidup) | ⚠️ sebagian | `AnemiaLogic` (modul edukasi/edukasi manual) memakai ambang 12.0 + keparahan; pipeline skrining binary = cut-off 120 g/L flat |
| Badge Normal/Ringan/Sedang/Berat | ⚠️ sebagian | Di dashboard & edukasi manual (dari Hb lab); hasil skrining ML = binary indikasi |
| Rekomendasi tatalaksana | ⚠️ sebagian | Fuzzy: pesan tindak lanjut + disclaimer; dosis TTD/Isi Piringku eksplisit = roadmap konten |
| Red flag Hb < 8 | ⚠️ sebagian | `TingkatAnemia.berat` di AnemiaLogic (dipakai dashboard, belum di output skrining) |
| DW star schema + dashboard tren | ✅ diadopsi | dim_* + fact + ETL + web admin |
| Sync SQLite → cloud | ⚠️ sebagian | Riwayat lokal + per akun Cloud; sinkronisasi penuh = roadmap |
| FastAPI (vs Flask) | ✅ diadopsi | Sidecar FastAPI |
| Dataset Mendeley | ❌ deviasi | Pakai Kaggle (ghana/nature, latih) + figshare (uji PCD/rantai) — lisensi & jumlah gambar lebih jelas |
| Negative testing buram | ✅ baru | 400 blur terverifikasi; test suite app tetap 74/74 |

Ringkasan: komponen yang ditolak (GPS, berat badan, regresi Hb sebagai output
utama, dataset Mendeley) ditolak dengan alasan terukur, bukan karena luput.
Yang bisa dikejar tanpa risiko besar tetap tercatat di roadmap.

> _Dokumen bersifat hidup — diupdate seiring keputusan tim & hasil eksplorasi._