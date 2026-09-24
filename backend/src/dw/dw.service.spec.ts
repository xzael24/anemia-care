import { DataSource } from 'typeorm';
import { DwService } from './dw.service';

/** DataSource palsu — cukup implementasi query() yang dipakai service. */
function fakeDataSource(
  answer: Record<string, unknown[]>,
): DataSource {
  return {
    query: async (sql: string) => {
      if (sql.includes('CREATE SCHEMA IF NOT EXISTS dw')) return [];
      if (sql.includes('CREATE OR REPLACE FUNCTION dw.sync_skrining')) return [];
      if (sql.includes('ON CONFLICT (tanggal) DO NOTHING')) return [];
      if (sql.includes('AVG(f.confidence)')) return (answer.summary ?? []) as never;
      if (sql.includes('GROUP BY w.tanggal')) return (answer.trend ?? []) as never;
      return [] as never;
    },
  } as unknown as DataSource;
}

describe('DwService', () => {
  it('ensureDw menjalankan DDL, trigger, dan backfill (3 query)', async () => {
    let calls = 0;
    const ds = {
      query: async () => {
        calls += 1;
        return [];
      },
    } as unknown as DataSource;

    const dw = new DwService(ds);
    await dw.ensureDw();
    await dw.ensureDw(); // kedua: idempoten, tidak query lagi
    expect(calls).toBe(3);
  });

  it('summary mem-parse angka (termasuk rate & avg dari numeric string)', async () => {
    const dw = new DwService(
      fakeDataSource({
        summary: [
          {
            total: 12,
            anemia: 5,
            normal: 7,
            verified: 3,
            anemia_rate_pct: '41.7',
            avg_confidence: '0.881',
          },
        ],
      }),
    );

    const s = await dw.summary();
    expect(s.total).toBe(12);
    expect(s.anemia).toBe(5);
    expect(s.normal).toBe(7);
    expect(s.verified).toBe(3);
    expect(s.anemiaRatePct).toBeCloseTo(41.7);
    expect(s.avgConfidence).toBeCloseTo(0.881);
  });

  it('summary aman saat belum ada data (baris kosong → nol)', async () => {
    const dw = new DwService(fakeDataSource({}));
    const s = await dw.summary();
    expect(s).toEqual({
      total: 0,
      anemia: 0,
      normal: 0,
      verified: 0,
      anemiaRatePct: null,
      avgConfidence: null,
    });
  });

  it('trend memetakan baris + melempar hari ke rentang 1–90', async () => {
    const dw = new DwService(
      fakeDataSource({
        trend: [
          { tanggal: '2026-09-24', total: 4, anemia: 3, normal: 1 },
          { tanggal: '2026-09-23', total: 2, anemia: 0, normal: 2 },
        ],
      }),
    );
    // const clamp diuji lewat nilai ekstrem — service tidak boleh error
    const t = await dw.trend(0);
    expect(t).toHaveLength(2);
    expect(t[0]).toMatchObject({ tanggal: '2026-09-24', total: 4, anemia: 3, normal: 1 });
    expect(t[1].anemia).toBe(0);
  });

  it('trend menormalkan tanggal Date (driver pg) ke YYYY-MM-DD', async () => {
    const dw = new DwService(
      fakeDataSource({
        trend: [
          { tanggal: new Date(2026, 8, 24), total: 9, anemia: 8, normal: 1 },
          { tanggal: '2026-09-23T00:00:00.000Z', total: 2, anemia: 1, normal: 1 },
        ],
      }),
    );
    const t = await dw.trend(30);
    expect(t[0].tanggal).toBe('2026-09-24');
    expect(t[1].tanggal).toBe('2026-09-23');
  });
});