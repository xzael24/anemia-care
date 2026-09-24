import { useEffect, useMemo, useState } from 'react';
import { api } from './api';
import type { DwSummary, DwTrendPoint, Screening } from './api';

interface Props {
  onLogout: () => void;
}

type Filter = 'semua' | 'anemia' | 'normal';

const fmtTime = (iso: string) =>
  new Date(iso).toLocaleString('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });

const TREND_DAYS = 14;

export default function DashboardPage({ onLogout }: Props) {
  const [rows, setRows] = useState<Screening[]>([]);
  const [filter, setFilter] = useState<Filter>('semua');
  const [error, setError] = useState('');
  const [loadError, setLoadError] = useState('');
  const [busyId, setBusyId] = useState<string | null>(null);
  const [dw, setDw] = useState<{
    summary: DwSummary;
    trend: DwTrendPoint[];
  } | null>(null);
  const [dwError, setDwError] = useState('');

  async function load() {
    setLoadError('');
    try {
      setRows(await api.screenings());
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat data');
    }
  }

  async function loadDw() {
    setDwError('');
    try {
      const [summary, trend] = await Promise.all([
        api.dwSummary(),
        api.dwTrend(TREND_DAYS),
      ]);
      setDw({ summary, trend });
    } catch (err) {
      setDwError(err instanceof Error ? err.message : 'DW tidak tersedia');
    }
  }

  useEffect(() => {
    void load();
    void loadDw();
  }, []);

  async function verify(id: string) {
    setBusyId(id);
    setError('');
    try {
      const updated = await api.verify(id);
      setRows((prev) => prev.map((r) => (r.id === id ? updated : r)));
      void loadDw(); // status verifikasi ikut ter-ETL ke DW (trigger)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Verifikasi gagal');
    } finally {
      setBusyId(null);
    }
  }

  const stats = useMemo(() => {
    const anemia = rows.filter((r) => r.indication === 'anemia').length;
    const normal = rows.filter((r) => r.indication === 'normal').length;
    const verified = rows.filter((r) => r.status === 'terverifikasi').length;
    return { total: rows.length, anemia, normal, verified };
  }, [rows]);

  const filtered =
    filter === 'semua'
      ? rows
      : rows.filter((r) => r.indication === filter);

  return (
    <div className="shell">
      <header className="topbar">
        <div className="brand">
          <span className="brand-ico">🩸</span> Anemia Care
          <span className="brand-tag">Admin Monitoring</span>
        </div>
        <button className="btn-ghost" onClick={onLogout}>
          Keluar
        </button>
      </header>

      <main className="content">
        {loadError && <div className="error-box">{loadError}</div>}
        {error && <div className="error-box">{error}</div>}

        <section className="stats">
          <div className="card stat">
            <div className="stat-num">{stats.total}</div>
            <div className="stat-label">Total Skrining</div>
          </div>
          <div className="card stat stat-anemia">
            <div className="stat-num">{stats.anemia}</div>
            <div className="stat-label">Indikasi Anemia</div>
          </div>
          <div className="card stat stat-normal">
            <div className="stat-num">{stats.normal}</div>
            <div className="stat-label">Indikasi Normal</div>
          </div>
          <div className="card stat">
            <div className="stat-num">{stats.verified}</div>
            <div className="stat-label">Terverifikasi</div>
          </div>
        </section>

        <section className="card dw-card">
          <div className="dw-head">
            <div>
              <h2>Tren Skrining · {TREND_DAYS} Hari</h2>
              <p className="muted">
                Sumber: Data Warehouse (ETL real-time dari tabel skrining)
              </p>
            </div>
            {dw && (
              <div className="dw-meta">
                <span className="dw-rate">
                  Indikasi anemia:{' '}
                  {dw.summary.anemiaRatePct == null
                    ? '—'
                    : `${dw.summary.anemiaRatePct}%`}
                </span>
                <span className="dw-akun">
                  {dw.summary.pasien > 0
                    ? `${dw.summary.pasien} dari akun pasien`
                    : 'Belum ada skrining ber-akun'}
                </span>
                <span className="dw-leg">
                  <i className="dot dot-anemia" /> anemia
                  <i className="dot dot-normal" /> normal
                </span>
              </div>
            )}
          </div>

          {dw && dw.trend.length > 0 ? (
            <div
              className="bars"
              role="img"
              aria-label={`Grafik batang tren skrining ${dw.trend.length} hari terakhir`}
            >
              {dw.trend.map((p) => {
                const max = Math.max(...dw.trend.map((x) => x.total), 1);
                const hAnemia = Math.round((p.anemia / max) * 100);
                const hNormal = Math.round((p.normal / max) * 100);
                return (
                  <div
                    className="bar-col"
                    key={p.tanggal}
                    title={`${p.tanggal}: ${p.total} skrining (${p.anemia} anemia, ${p.normal} normal)`}
                  >
                    <div className="bar-total">{p.total > 0 ? p.total : ''}</div>
                    <div className="bar-track">
                      {hAnemia > 0 && (
                        <div
                          className="bar-seg bar-anemia"
                          style={{ height: `${hAnemia}%` }}
                        />
                      )}
                      {hNormal > 0 && (
                        <div
                          className={
                            hAnemia > 0
                              ? 'bar-seg bar-normal bar-top'
                              : 'bar-seg bar-normal'
                          }
                          style={{ height: `${hNormal}%` }}
                        />
                      )}
                    </div>
                    <div className="bar-label">
                      {Number(p.tanggal.slice(8, 10))}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : dw ? (
            <p className="empty">
              Belum ada data DW untuk tren. Data muncul setelah skrining
              pertama dikirim.
            </p>
          ) : (
            <p className="muted">
              Data Warehouse tidak tersedia: {dwError || 'belum dimuat'}.
            </p>
          )}
        </section>

        <section className="card table-card">
          <div className="table-head">
            <h2>Riwayat Skrining</h2>
            <div className="filters">
              {(['semua', 'anemia', 'normal'] as Filter[]).map((f) => (
                <button
                  key={f}
                  className={filter === f ? 'chip chip-active' : 'chip'}
                  onClick={() => setFilter(f)}
                >
                  {f === 'semua' ? 'Semua' : f === 'anemia' ? 'Anemia' : 'Normal'}
                </button>
              ))}
            </div>
          </div>

          {filtered.length === 0 ? (
            <p className="empty">
              Belum ada hasil skrining. Foto kuku lewat aplikasi mobile akan
              muncul di sini.
            </p>
          ) : (
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Waktu</th>
                    <th>Foto</th>
                    <th>Pasien</th>
                    <th>Indikasi</th>
                    <th>Confidence</th>
                    <th>Sumber</th>
                    <th>Status</th>
                    <th>Diverifikasi oleh</th>
                    <th>Aksi</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r) => (
                    <tr key={r.id}>
                      <td className="nowrap">{fmtTime(r.createdAt)}</td>
                      <td title={r.imageName}>{r.imageName}</td>
                      <td className="nowrap">
                        {r.pasien
                          ? r.pasien.nama || `@${r.pasien.username}`
                          : '—'}
                      </td>
                      <td>
                        <span
                          className={
                            r.indication === 'anemia'
                              ? 'badge badge-anemia'
                              : 'badge badge-normal'
                          }
                        >
                          {r.indication === 'anemia' ? 'Anemia' : 'Normal'}
                        </span>
                      </td>
                      <td className="nowrap">
                        {(r.confidence * 100).toFixed(0)}%
                      </td>
                      <td>
                        <span
                          className={
                            r.source === 'ml' ? 'badge badge-ml' : 'badge badge-mock'
                          }
                        >
                          {r.source === 'ml' ? 'ML model' : 'Mock'}
                        </span>
                      </td>
                      <td>
                        <span
                          className={
                            r.status === 'terverifikasi'
                              ? 'badge badge-ok'
                              : 'badge badge-new'
                          }
                        >
                          {r.status === 'terverifikasi'
                            ? 'Diverifikasi'
                            : 'Baru'}
                        </span>
                      </td>
                      <td className="nowrap">{r.verifiedBy ?? '—'}</td>
                      <td>
                        {r.status === 'baru' ? (
                          <button
                            className="btn-verify"
                            disabled={busyId === r.id}
                            onClick={() => void verify(r.id)}
                          >
                            {busyId === r.id ? '…' : 'Verifikasi'}
                          </button>
                        ) : (
                          <span className="muted">Selesai</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <p className="disclaimer">
          ⚠️ Hasil skrining adalah indikasi awal, BUKAN diagnosis medis.
          Konsultasikan ke tenaga kesehatan untuk pemeriksaan darah (Hb) resmi.
        </p>
      </main>
    </div>
  );
}