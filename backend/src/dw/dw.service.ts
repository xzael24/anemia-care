import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

/**
 * Lapisan 3 capstone: Data Warehouse (star schema) di Postgres yang sama.
 *
 * - Schema `dw`: dim_waktu + dim_hasil + **dim_pasien** + fact_skrining
 *   (KONSEP §LAPISAN 3).
 * - ETL: (a) trigger AFTER INSERT/UPDATE di `public.screening` → sinkron
 *   real-time (termasuk saat status verifikasi berubah); (b) backfill
 *   idempotent saat service start untuk baris lama; (c) query agregat
 *   di-serve lewat controller ini ke web admin.
 * - dim_pasien terisi dari akun pengguna (fitur Tahap 3): screening yang
 *   dibuat dengan token pasien tercatat siapa pemiliknya. dim_lokasi belum
 *   dibuat (fitur konteks lokasi/kader menyusul).
 */
@Injectable()
export class DwService implements OnApplicationBootstrap {
  constructor(@InjectDataSource() private readonly ds: DataSource) {}

  private _sqlReady = false;

  async onApplicationBootstrap(): Promise<void> {
    await this.ensureDw();
  }

  /** Buat schema/dim/fact/trigger + backfill — aman dipanggil berulang. */
  async ensureDw(): Promise<void> {
    if (this._sqlReady) return;
    await this.ds.query(this._ddl);
    await this.ds.query(this._trigger);
    await this.ds.query(this._backfill);
    this._sqlReady = true;
  }

  /** Ringkasan agregat seluruh DW. */
  async summary(): Promise<DwSummary> {
    await this.ensureDw();
    const rows = (await this.ds.query(this._querySummary)) as Row[];
    const r = rows[0] ?? {};
    return {
      total: this._num(r.total),
      anemia: this._num(r.anemia),
      normal: this._num(r.normal),
      verified: this._num(r.verified),
      anemiaRatePct: r.anemia_rate_pct == null ? null : Number(r.anemia_rate_pct),
      avgConfidence: r.avg_confidence == null ? null : Number(r.avg_confidence),
      pasien: this._num(r.pasien),
      perempuan: this._num(r.perempuan),
      laki: this._num(r.laki),
    };
  }

  /** Tren harian N hari terakhir (default 30, dibatasi 1–90). */
  async trend(days: number): Promise<DwTrendPoint[]> {
    await this.ensureDw();
    const safe = Math.min(90, Math.max(1, Number.isFinite(days) ? days : 30));
    const rows = (await this.ds.query(this._queryTrend, [
      safe,
    ])) as Row[];
    return rows.map((r) => ({
      tanggal: this._fmtDate(r.tanggal),
      total: this._num(r.total),
      anemia: this._num(r.anemia),
      normal: this._num(r.normal),
    }));
  }

  private _num(v: unknown): number {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  /** pg mengembalikan kolom DATE sebagai Date; serealikan 'YYYY-MM-DD' (lokal, tanpa geser zona). */
  private _fmtDate(v: unknown): string {
    if (v instanceof Date) {
      const m = String(v.getMonth() + 1).padStart(2, '0');
      const d = String(v.getDate()).padStart(2, '0');
      return `${v.getFullYear()}-${m}-${d}`;
    }
    const s = String(v);
    return s.length >= 10 ? s.slice(0, 10) : s;
  }

  // ---------------------------------------------------------------------------

  private readonly _ddl = `
CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE IF NOT EXISTS dw.dim_waktu (
  id SERIAL PRIMARY KEY,
  tanggal DATE NOT NULL UNIQUE,
  tahun SMALLINT NOT NULL,
  bulan SMALLINT NOT NULL,
  nama_bulan TEXT NOT NULL,
  hari SMALLINT NOT NULL,
  nama_hari TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.dim_hasil (
  id SERIAL PRIMARY KEY,
  kelas_hasil TEXT NOT NULL,
  status_verifikasi TEXT NOT NULL,
  sumber TEXT NOT NULL,
  UNIQUE (kelas_hasil, status_verifikasi, sumber)
);

CREATE TABLE IF NOT EXISTS dw.dim_pasien (
  id SERIAL PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  nama TEXT NOT NULL,
  usia SMALLINT,
  gender TEXT,
  tipe_kulit TEXT,
  hamil BOOLEAN,
  riwayat_anemia BOOLEAN
);

CREATE TABLE IF NOT EXISTS dw.fact_skrining (
  skrining_id UUID PRIMARY KEY,
  dim_waktu_id INTEGER NOT NULL REFERENCES dw.dim_waktu(id),
  dim_hasil_id INTEGER NOT NULL REFERENCES dw.dim_hasil(id),
  dim_pasien_id INTEGER,
  confidence DOUBLE PRECISION NOT NULL,
  hb_estimate DOUBLE PRECISION
);

ALTER TABLE dw.fact_skrining ADD COLUMN IF NOT EXISTS dim_pasien_id INTEGER;

CREATE INDEX IF NOT EXISTS idx_fact_waktu ON dw.fact_skrining (dim_waktu_id);
CREATE INDEX IF NOT EXISTS idx_fact_hasil ON dw.fact_skrining (dim_hasil_id);
CREATE INDEX IF NOT EXISTS idx_fact_pasien ON dw.fact_skrining (dim_pasien_id);
`;

  private readonly _trigger = `
CREATE OR REPLACE FUNCTION dw.sync_skrining() RETURNS TRIGGER AS $$
DECLARE
  w_id INTEGER;
  h_id INTEGER;
  p_id INTEGER;
BEGIN
  INSERT INTO dw.dim_waktu (tanggal, tahun, bulan, nama_bulan, hari, nama_hari)
  VALUES (
    (NEW."createdAt")::date,
    EXTRACT(YEAR FROM NEW."createdAt")::INTEGER,
    EXTRACT(MONTH FROM NEW."createdAt")::INTEGER,
    TO_CHAR(NEW."createdAt", 'TMMonth'),
    EXTRACT(DAY FROM NEW."createdAt")::INTEGER,
    TO_CHAR(NEW."createdAt", 'TMDay')
  )
  ON CONFLICT (tanggal) DO UPDATE SET tanggal = EXCLUDED.tanggal
  RETURNING id INTO w_id;

  INSERT INTO dw.dim_hasil (kelas_hasil, status_verifikasi, sumber)
  VALUES (NEW.indication, NEW.status, NEW.source)
  ON CONFLICT (kelas_hasil, status_verifikasi, sumber) DO UPDATE
    SET kelas_hasil = EXCLUDED.kelas_hasil
  RETURNING id INTO h_id;

  -- Skrining ber-akun → (upsert) dimensi pasien, lalu tautkan fact.
  IF NEW."pasienId" IS NOT NULL THEN
    INSERT INTO dw.dim_pasien (username, nama, usia, gender, tipe_kulit, hamil, riwayat_anemia)
    SELECT pa.username, pa.nama, pa.usia, pa.gender, pa."tipeKulit", pa.hamil, pa."riwayatAnemia"
    FROM public.pasien pa
    WHERE pa.id::text = NEW."pasienId"
    ON CONFLICT (username) DO UPDATE SET
      nama = EXCLUDED.nama,
      usia = EXCLUDED.usia,
      gender = EXCLUDED.gender,
      tipe_kulit = EXCLUDED.tipe_kulit,
      hamil = EXCLUDED.hamil,
      riwayat_anemia = EXCLUDED.riwayat_anemia
    RETURNING id INTO p_id;
  END IF;

  INSERT INTO dw.fact_skrining (skrining_id, dim_waktu_id, dim_hasil_id, dim_pasien_id, confidence, hb_estimate)
  VALUES (NEW.id, w_id, h_id, p_id, NEW.confidence, NEW."hbEstimateGdl")
  ON CONFLICT (skrining_id) DO UPDATE SET
    dim_waktu_id = EXCLUDED.dim_waktu_id,
    dim_hasil_id = EXCLUDED.dim_hasil_id,
    dim_pasien_id = EXCLUDED.dim_pasien_id,
    confidence = EXCLUDED.confidence,
    hb_estimate = EXCLUDED.hb_estimate;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_dw_skrining ON public.screening;
CREATE TRIGGER trg_dw_skrining
AFTER INSERT OR UPDATE OF indication, status, source, confidence, "hbEstimateGdl", "pasienId"
ON public.screening
FOR EACH ROW EXECUTE FUNCTION dw.sync_skrining();
`;

  private readonly _backfill = `
INSERT INTO dw.dim_waktu (tanggal, tahun, bulan, nama_bulan, hari, nama_hari)
SELECT DISTINCT
  ("createdAt")::date,
  EXTRACT(YEAR FROM "createdAt")::INTEGER,
  EXTRACT(MONTH FROM "createdAt")::INTEGER,
  TO_CHAR("createdAt", 'TMMonth'),
  EXTRACT(DAY FROM "createdAt")::INTEGER,
  TO_CHAR("createdAt", 'TMDay')
FROM public.screening
ON CONFLICT (tanggal) DO NOTHING;

INSERT INTO dw.dim_hasil (kelas_hasil, status_verifikasi, sumber)
SELECT DISTINCT indication, status, source
FROM public.screening
ON CONFLICT (kelas_hasil, status_verifikasi, sumber) DO NOTHING;

INSERT INTO dw.dim_pasien (username, nama, usia, gender, tipe_kulit, hamil, riwayat_anemia)
SELECT DISTINCT pa.username, pa.nama, pa.usia, pa.gender, pa."tipeKulit", pa.hamil, pa."riwayatAnemia"
FROM public.pasien pa
ON CONFLICT (username) DO UPDATE SET
  nama = EXCLUDED.nama,
  usia = EXCLUDED.usia,
  gender = EXCLUDED.gender,
  tipe_kulit = EXCLUDED.tipe_kulit,
  hamil = EXCLUDED.hamil,
  riwayat_anemia = EXCLUDED.riwayat_anemia;

INSERT INTO dw.fact_skrining (skrining_id, dim_waktu_id, dim_hasil_id, dim_pasien_id, confidence, hb_estimate)
SELECT
  s.id,
  w.id,
  h.id,
  pd.id,
  s.confidence,
  s."hbEstimateGdl"
FROM public.screening s
JOIN dw.dim_waktu w ON w.tanggal = s."createdAt"::date
JOIN dw.dim_hasil h
  ON h.kelas_hasil = s.indication
 AND h.status_verifikasi = s.status
 AND h.sumber = s.source
LEFT JOIN public.pasien pa ON pa.id::text = s."pasienId"
LEFT JOIN dw.dim_pasien pd ON pd.username = pa.username
ON CONFLICT (skrining_id) DO UPDATE SET
  dim_waktu_id = EXCLUDED.dim_waktu_id,
  dim_hasil_id = EXCLUDED.dim_hasil_id,
  dim_pasien_id = EXCLUDED.dim_pasien_id,
  confidence = EXCLUDED.confidence,
  hb_estimate = EXCLUDED.hb_estimate;
`;

  private readonly _querySummary = `
SELECT
  (COUNT(*))::int AS total,
  (COUNT(*) FILTER (WHERE h.kelas_hasil = 'anemia'))::int AS anemia,
  (COUNT(*) FILTER (WHERE h.kelas_hasil = 'normal'))::int AS normal,
  (COUNT(*) FILTER (WHERE h.status_verifikasi = 'terverifikasi'))::int AS verified,
  ROUND(100.0 * (COUNT(*) FILTER (WHERE h.kelas_hasil = 'anemia')) / NULLIF(COUNT(*), 0), 1) AS anemia_rate_pct,
  ROUND(AVG(f.confidence)::numeric, 3) AS avg_confidence,
  (COUNT(DISTINCT f.dim_pasien_id))::int AS pasien,
  (COUNT(*) FILTER (WHERE p.gender = 'perempuan'))::int AS perempuan,
  (COUNT(*) FILTER (WHERE p.gender = 'laki'))::int AS laki
FROM dw.fact_skrining f
JOIN dw.dim_hasil h ON h.id = f.dim_hasil_id
LEFT JOIN dw.dim_pasien p ON p.id = f.dim_pasien_id;
`;

  private readonly _queryTrend = `
SELECT
  w.tanggal,
  (COUNT(*))::int AS total,
  (COUNT(*) FILTER (WHERE h.kelas_hasil = 'anemia'))::int AS anemia,
  (COUNT(*) FILTER (WHERE h.kelas_hasil = 'normal'))::int AS normal
FROM dw.fact_skrining f
JOIN dw.dim_waktu w ON w.id = f.dim_waktu_id
JOIN dw.dim_hasil h ON h.id = f.dim_hasil_id
WHERE w.tanggal >= CURRENT_DATE - $1::int + 1
GROUP BY w.tanggal
ORDER BY w.tanggal;
`;
}

export interface DwSummary {
  total: number;
  anemia: number;
  normal: number;
  verified: number;
  anemiaRatePct: number | null;
  avgConfidence: number | null;
  /** Jumlah skrining yang berasal dari akun pasien (dim_pasien). */
  pasien: number;
  perempuan: number;
  laki: number;
}

export interface DwTrendPoint {
  tanggal: string; // 'YYYY-MM-DD'
  total: number;
  anemia: number;
  normal: number;
}

type Row = Record<string, unknown>;