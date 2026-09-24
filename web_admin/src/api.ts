export interface Screening {
  id: string;
  indication: 'anemia' | 'normal';
  confidence: number;
  hbEstimateGdl: number | null;
  source: 'ml' | 'mock';
  imageName: string;
  createdAt: string;
  status: 'baru' | 'terverifikasi';
  verifiedBy: string | null;
  verifiedAt: string | null;
}

export interface Petugas {
  id: string;
  username: string;
  name: string;
  role: string;
}

/** Lapisan 3 — Data Warehouse (ETL real-time dari tabel skrining). */
export interface DwSummary {
  total: number;
  anemia: number;
  normal: number;
  verified: number;
  anemiaRatePct: number | null;
  avgConfidence: number | null;
}

export interface DwTrendPoint {
  tanggal: string; // 'YYYY-MM-DD'
  total: number;
  anemia: number;
  normal: number;
}

const API_BASE: string =
  (import.meta.env.VITE_API_URL as string | undefined) ??
  'http://localhost:3000/api';

const TOKEN_KEY = 'anemia_admin_token';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}
export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}
export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getToken();
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init?.headers ?? {}),
    },
  });
  if (res.status === 401) {
    clearToken();
    throw new Error('Sesi berakhir, silakan login ulang');
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as
      | { message?: string }
      | null;
    throw new Error(body?.message ?? `HTTP ${res.status}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  login: (username: string, password: string) =>
    request<{ accessToken: string; petugas: Petugas }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),
  screenings: () => request<Screening[]>('/screening'),
  verify: (id: string) =>
    request<Screening>(`/screening/${id}/verify`, { method: 'PATCH' }),
  dwSummary: () => request<DwSummary>('/dashboard/summary'),
  dwTrend: (days = 14) =>
    request<DwTrendPoint[]>(`/dashboard/trend?days=${days}`),
};