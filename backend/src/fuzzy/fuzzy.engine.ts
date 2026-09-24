/**
 * Mesin Fuzzy Mamdani murni (tanpa dependensi) untuk rekomendasi tindak
 * lanjut skrining anemia (PSC1).
 *
 * Input crisp 0..1:
 *  - `visual`  : kekuatan indikasi visual ML (0 = normal kuat, 1 = pucat kuat)
 *  - `gejala`  : banyaknya gejala yang dipilih pengguna (0..1)
 *  - `risiko`  : banyaknya faktor risiko (menstruasi/hamil/riwayat/diet) (0..1)
 *
 * Inferensi max–min (Mamdani), agregasi clip-then-max, defuzzifikasi centroid.
 */

export type Tingkat = 'rendah' | 'sedang' | 'tinggi';

type TermVisual = 'KURANG' | 'SEDANG' | 'TINGGI';
type TermGejala = 'TIDAK' | 'ADA';
type TermRisiko = 'RENDAH' | 'TINGGI';
type Mf = (x: number) => number;

/** Trapesium: datar 1 di [b,c], landai ke 0 di luar [a,d]. Aman untuk tepi
 * degenerasi (a==b atau c==d), mis. shoulder yang mulai tepat di 0 / berakhir di 1. */
const trapes =
  (a: number, b: number, c: number, d: number): Mf =>
  (x) => {
    if (x < a || x > d) return 0;
    if (x >= b && x <= c) return 1;
    if (x < b) return (x - a) / (b - a);
    return (d - x) / (d - c); // c < x < d
  };

/** Segitiga dengan puncak di b. */
const segitiga =
  (a: number, b: number, c: number): Mf =>
  (x) => {
    if (x <= a || x >= c) return 0;
    if (x < b) return (x - a) / (b - a);
    return (c - x) / (c - b);
  };

// Fungsi keanggotaan input — antar himpunan sengaja di-overlap agar selalu
// ada minimal satu rule aktif (tidak ada celah di 0.5).
const MF_VISUAL: Record<TermVisual, Mf> = {
  KURANG: trapes(0, 0, 0.3, 0.45),
  SEDANG: segitiga(0.25, 0.5, 0.75),
  TINGGI: trapes(0.55, 0.7, 1, 1),
};

const MF_GEJALA: Record<TermGejala, Mf> = {
  TIDAK: trapes(0, 0, 0.35, 0.55),
  ADA: trapes(0.45, 0.65, 1, 1),
};

const MF_RISIKO: Record<TermRisiko, Mf> = {
  RENDAH: trapes(0, 0, 0.3, 0.55),
  TINGGI: trapes(0.45, 0.7, 1, 1),
};

// Fungsi keanggotaan output (rekomendasi).
const MF_OUTPUT: Record<Tingkat, Mf> = {
  rendah: trapes(0, 0, 0.15, 0.35),
  sedang: segitiga(0.15, 0.5, 0.85),
  tinggi: trapes(0.65, 0.85, 1, 1),
};

interface Rule {
  visual?: TermVisual;
  gejala?: TermGejala;
  risiko?: TermRisiko;
  output: Tingkat;
  deskripsi: string;
}

const RULES: Rule[] = [
  { visual: 'KURANG', gejala: 'TIDAK', risiko: 'RENDAH', output: 'rendah', deskripsi: 'IF visual=KURANG AND gejala=TIDAK AND risiko=RENDAH THEN rekomendasi=RENDAH' },
  { visual: 'KURANG', gejala: 'TIDAK', risiko: 'TINGGI', output: 'sedang', deskripsi: 'IF visual=KURANG AND gejala=TIDAK AND risiko=TINGGI THEN rekomendasi=SEDANG' },
  { visual: 'KURANG', gejala: 'ADA', risiko: 'RENDAH', output: 'sedang', deskripsi: 'IF visual=KURANG AND gejala=ADA AND risiko=RENDAH THEN rekomendasi=SEDANG' },
  { visual: 'KURANG', gejala: 'ADA', risiko: 'TINGGI', output: 'sedang', deskripsi: 'IF visual=KURANG AND gejala=ADA AND risiko=TINGGI THEN rekomendasi=SEDANG' },
  { visual: 'SEDANG', gejala: 'TIDAK', risiko: 'RENDAH', output: 'sedang', deskripsi: 'IF visual=SEDANG AND gejala=TIDAK AND risiko=RENDAH THEN rekomendasi=SEDANG' },
  { visual: 'SEDANG', gejala: 'TIDAK', risiko: 'TINGGI', output: 'sedang', deskripsi: 'IF visual=SEDANG AND gejala=TIDAK AND risiko=TINGGI THEN rekomendasi=SEDANG' },
  { visual: 'SEDANG', gejala: 'ADA', risiko: 'RENDAH', output: 'sedang', deskripsi: 'IF visual=SEDANG AND gejala=ADA AND risiko=RENDAH THEN rekomendasi=SEDANG' },
  { visual: 'SEDANG', gejala: 'ADA', risiko: 'TINGGI', output: 'tinggi', deskripsi: 'IF visual=SEDANG AND gejala=ADA AND risiko=TINGGI THEN rekomendasi=TINGGI' },
  { visual: 'TINGGI', gejala: 'TIDAK', risiko: 'RENDAH', output: 'tinggi', deskripsi: 'IF visual=TINGGI AND gejala=TIDAK AND risiko=RENDAH THEN rekomendasi=TINGGI' },
  { visual: 'TINGGI', gejala: 'TIDAK', risiko: 'TINGGI', output: 'tinggi', deskripsi: 'IF visual=TINGGI AND gejala=TIDAK AND risiko=TINGGI THEN rekomendasi=TINGGI' },
  { visual: 'TINGGI', gejala: 'ADA', risiko: 'RENDAH', output: 'tinggi', deskripsi: 'IF visual=TINGGI AND gejala=ADA AND risiko=RENDAH THEN rekomendasi=TINGGI' },
  { visual: 'TINGGI', gejala: 'ADA', risiko: 'TINGGI', output: 'tinggi', deskripsi: 'IF visual=TINGGI AND gejala=ADA AND risiko=TINGGI THEN rekomendasi=TINGGI' },
];

export interface FiredRule {
  deskripsi: string;
  bobot: number;
  output: Tingkat;
}

export interface InferResult {
  /** Nilai crisp hasil defuzzifikasi centroid, 0..1. */
  nilai: number;
  /** Derajat keanggotaan tiap tingkat output setelah agregasi max. */
  derajat: Record<Tingkat, number>;
  /** Rule yang aktif (bobot > 0), terurut bobot turun. */
  rulesFired: FiredRule[];
}

const round = (n: number, p = 3) => Number(n.toFixed(p));

/** Klasifikasi nilai crisp → tingkat rekomendasi (ambang 0,34 / 0,67). */
export function klasifikasi(nilai: number): Tingkat {
  if (nilai < 0.34) return 'rendah';
  if (nilai >= 0.67) return 'tinggi';
  return 'sedang';
}

export function inferFuzzy(
  visual: number,
  gejala: number,
  risiko: number,
): InferResult {
  const v: Record<TermVisual, number> = {
    KURANG: MF_VISUAL.KURANG(visual),
    SEDANG: MF_VISUAL.SEDANG(visual),
    TINGGI: MF_VISUAL.TINGGI(visual),
  };
  const g: Record<TermGejala, number> = {
    TIDAK: MF_GEJALA.TIDAK(gejala),
    ADA: MF_GEJALA.ADA(gejala),
  };
  const r: Record<TermRisiko, number> = {
    RENDAH: MF_RISIKO.RENDAH(risiko),
    TINGGI: MF_RISIKO.TINGGI(risiko),
  };

  const derajat: Record<Tingkat, number> = { rendah: 0, sedang: 0, tinggi: 0 };
  const rulesFired: FiredRule[] = [];

  for (const rule of RULES) {
    const w = Math.min(
      rule.visual ? v[rule.visual] : 1,
      rule.gejala ? g[rule.gejala] : 1,
      rule.risiko ? r[rule.risiko] : 1,
    );
    if (w > 0.001) {
      rulesFired.push({
        deskripsi: rule.deskripsi,
        bobot: round(w),
        output: rule.output,
      });
      derajat[rule.output] = Math.max(derajat[rule.output], w);
    }
  }
  rulesFired.sort((a, b) => b.bobot - a.bobot);

  // Defuzzifikasi: centroid (cuplikan 101 titik pada [0,1]).
  const N = 101;
  let num = 0;
  let den = 0;
  for (let i = 0; i <= N; i += 1) {
    const x = i / N;
    let mu = 0;
    for (const t of ['rendah', 'sedang', 'tinggi'] as const) {
      mu = Math.max(mu, Math.min(MF_OUTPUT[t](x), derajat[t]));
    }
    num += x * mu;
    den += mu;
  }

  return {
    nilai: den > 0 ? round(num / den) : 0,
    derajat: {
      rendah: round(derajat.rendah),
      sedang: round(derajat.sedang),
      tinggi: round(derajat.tinggi),
    },
    rulesFired,
  };
}