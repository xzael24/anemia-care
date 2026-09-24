# Training Baselines — Alur Colab MCP

Artefak siapa-pakai:

| File | Fungsi |
|---|---|
| `data/upload/anemia_nail_dataset_v1.zip` | Dataset 2.907 gambar + CSV split, siap upload |
| `scripts/training/baselines_colab.ipynb` | Notebook pelatihan (build dari `build_notebook.py`) |
| `scripts/training/build_notebook.py` | Regenerasi notebook setelah edit sel |
| `scripts/training/make_upload_zip.py` | Regenerasi zip setelah ada perubahan dataset |
| `data/artifacts/baseline_metrics.json` | **Hasil run 2026-09-24** (feature-based + CNN) |
| `data/artifacts/anemia_model_v1.keras` | **Model CNN MobileNetV2 frozen** (threshold 0,65) |
| `data/artifacts/artifacts_v1.zip` | Kemasan model + metrik (arsip) |
| `data/artifacts/ft_metrics.json` | **Hasil iterasi fine-tune** (run ke-2, 2026-09-24) |
| `data/artifacts/anemia_model_v2_ft.keras` | **Model CNN MobileNetV2 fine-tuned** (threshold 0,60) |
| `data/artifacts/artifacts_v2.zip` | Kemasan v2 (arsip) |

Alur (dipakai run pertama, 2026-09-24):

1. **Colab dibuka** (`colab.research.google.com`) + connect via colab-mcp
   (`opencode mcp add colab-mcp -- uvx git+https://github.com/googlecolab/colab-mcp`).
2. Ganti runtime ke **T4 GPU** (Runtime → Change runtime type).
3. Notebook disusun di Colab (sel: setup → download → extract → split → fitur →
   feature-based → CNN → eval → regresi Hb → ekspor). Sumber sel = isi
   `baselines_colab.ipynb`; sel download/ekspor memakai host sementara.
4. Transfer file ke Colab (zip dataset) via **tunnel cloudflared** ke
   `python -m http.server` lokal (host publik lain diblokir/JS-gated di IP datacenter);
   hasil (model + metrik) keluar via **tmpfiles.org** -> diunduh ke `data/artifacts/`.
5. Verifikasi md5 di tiap transfer (`4af347f89e6926b1c7814d55254c83f7` untuk zip dataset).

Hasil baseline (test, per-pasien; label Hb `hb_g_dl` dalam g/dL):

| Model | acc | sens (recall anemic) | spec | prec | f1 | AUC |
|---|---|---|---|---|---|---|
| RandomForest (fitur 33D) | 0,780 | **0,789** | 0,771 | 0,738 | 0,763 | **0,846** |
| LogReg (fitur 33D) | 0,630 | 0,544 | 0,700 | 0,596 | 0,569 | 0,710 |
| GradientBoosting (fitur 33D) | 0,693 | 0,579 | 0,786 | 0,688 | 0,629 | 0,788 |
| CNN MobileNetV2 @th 0,65 | 0,586 | 0,541 | 0,627 | 0,571 | 0,556 | 0,646 |
| CNN MobileNetV2 fine-tuned @th 0,60 | 0,618 | 0,580 | 0,653 | 0,606 | 0,593 | 0,663 |

- CV-AUC GroupKFold (per pasien): LogReg 0,722 · RF 0,760 · GBM 0,745 → pilih **RF**.
- CNN v1 (frozen): early-stop epoch 10 (best val_auc ≈ 0,66 di epoch 6); di val @0,5 sens 0,89 /
  spec 0,37; threshold 0,65 (sens 0,63 / spec 0,58).
- **Iterasi fine-tune (v2)**: warm-start v1 → unfreeze 16 lapisan akhir base (BN
  tetap beku) → Adam 1e-4, augmentasi lebih kuat (rotasi/zoom/translasi/brightness/
  contrast/saturasi), early-stop epoch 8 (best val_auc 0,648). **Test membaik tipis**:
  sens 0,541 → 0,580, AUC 0,646 → 0,663 — masih jauh dari target sens ≥ 0,85.
- Regresi Hb (nature, n=40 pasien test): **RMSE ≈ 2,0 g/dL (≈20 g/L), R² = 0,36** —
  sebanding paper Yakimov 2024 (RMSE 20–24 g/L).

Kriteria sukses baseline:
- [x] Feature-based: model terbaik dipilih via GroupKFold, metrik test tercatat (RF: AUC 0,846)
- [ ] CNN: sens test ≥ 0,85 & spec ≥ 0,50 — **BELUM** (v1: sens 0,54; v2 fine-tune: sens 0,58).
      Iterasi fine-tune sudah dicoba (gain kecil); kesimpulan & opsi lanjut di bawah.
- [x] Regresi Hb: RMSE tercatat ≈ 20 g/L (≤ 24 g/L tercapai)
- [x] Artifak terunduh & md5 diverifikasi

Status & opsi lanjut (masih terbuka):
- **Model yang dipakai integrasi backend saat ini: RandomForest (sens 0,79 / spec 0,77 di test)**
  — cukup untuk demo skrining tahap awal; CNN bisa di-swap belakangan.
- Opsi menaikkan CNN (risiko gain kecil, butuh waktu riset): unfreeze lebih banyak
  layer + cosine LR + MixUp; pra-proses warna standar (kalibrasi white balance);
  tambah data lintas sumber. Alternatif pragmatis: **ensemble probabilitas RF + CNN**,
  atau perbaiki label representasi (3 kelas risiko + fuzzy, selaras PSC1).

> ⚠️ Semua keluaran adalah **indikasi awal skrining**, bukan diagnosis — disclaimer
> wajib muncul di produk akhir (app/web). Prioritas metrik: **sensitivitas**.