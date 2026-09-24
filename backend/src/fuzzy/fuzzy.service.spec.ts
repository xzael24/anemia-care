import { inferFuzzy, klasifikasi } from './fuzzy.engine';
import { FuzzyService } from './fuzzy.service';

describe('FuzzyService (PSC1)', () => {
  const svc = new FuzzyService();

  it('kasus KONSEP: visual normal + tanpa gejala/risiko → rekomendasi RENDAH', () => {
    const r = svc.rekomendasi({ indication: 'normal', confidence: 0.9 });
    expect(r.tingkat).toBe('rendah');
    expect(r.rekomendasi).toBeLessThan(0.34);
    expect(r.label).toContain('pola makan');
    expect(r.emoji).toBe('🟢');
    expect(r.aturanAktif.length).toBeGreaterThanOrEqual(1);
  });

  it('kasus KONSEP: visual pucat + hamil + pusing → TINGGI (segera periksa)', () => {
    const r = svc.rekomendasi({
      indication: 'anemia',
      confidence: 0.92,
      gejala: ['pusing', 'lemas'],
      risiko: ['hamil', 'menstruasi'],
      tipeKulit: 'gelap',
    });
    expect(r.tingkat).toBe('tinggi');
    expect(r.rekomendasi).toBeGreaterThanOrEqual(0.67);
    expect(r.label).toContain('puskesmas');
    expect(r.skor.visual).toBeGreaterThanOrEqual(0.9);
    expect(r.disclaimer).toContain('BUKAN pengganti tenaga kesehatan');
  });

  it('kasus KONSEP: visual sedang + menstruasi → SEDANG (asupan zat besi)', () => {
    const r = svc.rekomendasi({
      indication: 'normal',
      confidence: 0.5, // skor visual = 0.5 → SEDANG
      risiko: ['menstruasi'],
    });
    expect(r.tingkat).toBe('sedang');
    expect(r.rekomendasi).toBeGreaterThanOrEqual(0.34);
    expect(r.rekomendasi).toBeLessThan(0.67);
    expect(r.label).toContain('zat besi');
    expect(r.emoji).toBe('🟡');
  });

  it('estimasi Hb < 12 g/dL menaikkan skor visual walau indikasi normal', () => {
    const tanpaHb = svc.rekomendasi({ indication: 'normal', confidence: 0.9 });
    const denganHb = svc.rekomendasi({
      indication: 'normal',
      confidence: 0.9,
      hbEstimateGdl: 10.5,
    });
    expect(denganHb.skor.visual).toBeGreaterThan(tanpaHb.skor.visual);
    expect(denganHb.tingkat).not.toBe('rendah');
  });

  it('tipe kulit gelap membuat skor visual lebih konservatif', () => {
    const dasar = svc.rekomendasi({ indication: 'normal', confidence: 0.8 });
    const gelap = svc.rekomendasi({
      indication: 'normal',
      confidence: 0.8,
      tipeKulit: 'gelap',
    });
    expect(gelap.skor.visual).toBeGreaterThan(dasar.skor.visual);
  });

  it('aturan() mengembalikan 12 rule Mamdani', () => {
    expect(svc.aturan()).toHaveLength(12);
  });

  it('klasifikasi batas 0,34 / 0,67', () => {
    expect(klasifikasi(0.2)).toBe('rendah');
    expect(klasifikasi(0.5)).toBe('sedang');
    expect(klasifikasi(0.8)).toBe('tinggi');
  });
});

describe('inferFuzzy (engine murni)', () => {
  it('selalu menghasilkan nilai di [0,1] dan ≥1 rule aktif', () => {
    for (const [v, g, r] of [
      [0.5, 0.5, 0.5],
      [0, 0, 0],
      [1, 1, 1],
      [0.3, 0.7, 0.2],
    ] as const) {
      const res = inferFuzzy(v, g, r);
      expect(res.nilai).toBeGreaterThanOrEqual(0);
      expect(res.nilai).toBeLessThanOrEqual(1);
      expect(res.rulesFired.length).toBeGreaterThanOrEqual(1);
    }
  });

  it('visual sangat kuat → derajat tinggi maksimal', () => {
    const res = inferFuzzy(1, 0, 0);
    expect(res.derajat.tinggi).toBe(1);
    expect(res.derajat.rendah).toBe(0);
  });

  it('segalanya nol → derajat rendah maksimal', () => {
    const res = inferFuzzy(0.02, 0, 0);
    expect(res.derajat.rendah).toBe(1);
    expect(res.derajat.tinggi).toBe(0);
  });
});