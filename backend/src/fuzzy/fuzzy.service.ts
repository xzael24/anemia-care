import { Injectable } from '@nestjs/common';
import { inferFuzzy, klasifikasi, Tingkat } from './fuzzy.engine';

/** Pilihan gejala — label tampilan mobile/web. */
export const GEJALA_OPTIONS = [
  'pusing',
  'lemas',
  'berkunang',
  'pucat',
  'sesak',
] as const;
export const GEJALA_LABEL: Record<(typeof GEJALA_OPTIONS)[number], string> = {
  pusing: 'Pusing / sakit kepala',
  lemas: 'Lemas, cepat lelah',
  berkunang: 'Berkunang-kunang',
  pucat: 'Wajah / kuku tampak pucat',
  sesak: 'Sesak napas ringan',
};

/** Pilihan faktor risiko. */
export const RISIKO_OPTIONS = [
  'menstruasi',
  'hamil',
  'riwayat_anemia',
  'kurang_zat_besi',
] as const;
export const RISIKO_LABEL: Record<(typeof RISIKO_OPTIONS)[number], string> = {
  menstruasi: 'Menstruasi berat',
  hamil: 'Sedang hamil',
  riwayat_anemia: 'Riwayat anemia',
  kurang_zat_besi: 'Asupan zat besi kurang',
};

/** Tipe kulit — memengaruhi keterbacaan pucat kuku (gelap: lebih konservatif). */
export const KULIT_OPTIONS = ['terang', 'sedang', 'gelap'] as const;
export const KULIT_LABEL: Record<(typeof KULIT_OPTIONS)[number], string> = {
  terang: 'Terang',
  sedang: 'Sedang',
  gelap: 'Gelap',
};

export const TINGKAT_EMOJI: Record<Tingkat, string> = {
  rendah: '🟢',
  sedang: '🟡',
  tinggi: '🔴',
};

export const TINGKAT_LABEL: Record<Tingkat, string> = {
  rendah: 'Tetap pola makan sehat & skrining berkala',
  sedang:
    'Tingkatkan asupan zat besi (bayam, daging merah) + cek darah disarankan',
  tinggi: 'Segera periksa ke puskesmas/dokter — pemeriksaan darah (Hb)',
};

const DISCLAIMER =
  'Rekomendasi ini hasil gabungan indikasi visual + konteks pengguna, bersifat ' +
  'edukatif, BUKAN pengganti tenaga kesehatan. Konsultasikan ke faskes untuk ' +
  'pemeriksaan darah (Hb) resmi.';

export interface RekomendasiHasil {
  rekomendasi: number;
  tingkat: Tingkat;
  emoji: string;
  label: string;
  pesan: string;
  skor: { visual: number; gejala: number; risiko: number };
  aturanAktif: { deskripsi: string; bobot: number; output: Tingkat }[];
  disclaimer: string;
}

export interface RekomendasiRequest {
  indication: 'anemia' | 'normal';
  confidence: number;
  hbEstimateGdl?: number;
  gejala?: string[];
  risiko?: string[];
  tipeKulit?: 'terang' | 'sedang' | 'gelap';
}

const round = (n: number, p = 2) => Number(n.toFixed(p));

@Injectable()
export class FuzzyService {
  /** Hitung rekomendasi fuzzy dari hasil visual ML + konteks pengguna. */
  rekomendasi(req: RekomendasiRequest): RekomendasiHasil {
    // Skor visual: anemia → confidence; normal → 1 − confidence.
    let skorVisual =
      req.indication === 'anemia' ? req.confidence : 1 - req.confidence;

    // Estimasi Hb < ambang WHO (12 g/dL) → visual tidak boleh dianggap normal.
    if (req.hbEstimateGdl != null && req.hbEstimateGdl < 12) {
      skorVisual = Math.max(skorVisual, 0.6);
    }
    // Kulit gelap: pucat kurang terbaca → naikkan sedikit (prioritas sensitivitas).
    if (req.tipeKulit === 'gelap') skorVisual = Math.min(1, skorVisual + 0.1);
    if (req.tipeKulit === 'sedang') skorVisual = Math.min(1, skorVisual + 0.05);

    const skorGejala = Math.min(1, (req.gejala?.length ?? 0) * 0.2); // 5 gejala
    const skorRisiko = Math.min(1, (req.risiko?.length ?? 0) * 0.25); // 4 risiko

    const infer = inferFuzzy(
      round(skorVisual, 3),
      round(skorGejala, 3),
      round(skorRisiko, 3),
    );
    const tingkat = klasifikasi(infer.nilai);
    const utama = infer.rulesFired[0];

    let pesan: string;
    if (tingkat === 'tinggi') {
      pesan =
        'Indikasi visual (atau gabungan gejala/risiko) cukup kuat. Pemeriksaan ' +
        'darah (Hb) segera disarankan untuk memastikan kondisi.';
    } else if (tingkat === 'sedang') {
      pesan =
        'Ada tanda yang perlu diperhatikan. Perbaiki asupan zat besi dan ' +
        'lakukan cek darah bila keluhan menetap.';
    } else {
      pesan =
        'Tidak ada tanda mengkhawatirkan dari hasil skrining. Tetap jaga pola ' +
        'makan sehat dan lakukan skrining berkala.';
    }
    if (utama) pesan += ` (rule aktif: ${utama.deskripsi})`;

    return {
      rekomendasi: infer.nilai,
      tingkat,
      emoji: TINGKAT_EMOJI[tingkat],
      label: TINGKAT_LABEL[tingkat],
      pesan,
      skor: {
        visual: round(skorVisual),
        gejala: skorGejala,
        risiko: skorRisiko,
      },
      aturanAktif: infer.rulesFired.slice(0, 3),
      disclaimer: DISCLAIMER,
    };
  }

  /** Daftar rule fuzzy (dokumentasi diri untuk laporan PSC1). */
  aturan(): { deskripsi: string; output: Tingkat }[] {
    // Rule diambil dari engine via re-run pada titik sampel? Lebih jelas:
    // kembalikan tabel rule statis yang sama dengan engine.
    return [
      { deskripsi: 'visual=KURANG & gejala=TIDAK & risiko=RENDAH → RENDAH', output: 'rendah' },
      { deskripsi: 'visual=KURANG & gejala=TIDAK & risiko=TINGGI → SEDANG', output: 'sedang' },
      { deskripsi: 'visual=KURANG & gejala=ADA & risiko=RENDAH → SEDANG', output: 'sedang' },
      { deskripsi: 'visual=KURANG & gejala=ADA & risiko=TINGGI → SEDANG', output: 'sedang' },
      { deskripsi: 'visual=SEDANG & gejala=TIDAK & risiko=RENDAH → SEDANG', output: 'sedang' },
      { deskripsi: 'visual=SEDANG & gejala=TIDAK & risiko=TINGGI → SEDANG', output: 'sedang' },
      { deskripsi: 'visual=SEDANG & gejala=ADA & risiko=RENDAH → SEDANG', output: 'sedang' },
      { deskripsi: 'visual=SEDANG & gejala=ADA & risiko=TINGGI → TINGGI', output: 'tinggi' },
      { deskripsi: 'visual=TINGGI & gejala=TIDAK & risiko=RENDAH → TINGGI', output: 'tinggi' },
      { deskripsi: 'visual=TINGGI & gejala=TIDAK & risiko=TINGGI → TINGGI', output: 'tinggi' },
      { deskripsi: 'visual=TINGGI & gejala=ADA & risiko=RENDAH → TINGGI', output: 'tinggi' },
      { deskripsi: 'visual=TINGGI & gejala=ADA & risiko=TINGGI → TINGGI', output: 'tinggi' },
    ];
  }
}