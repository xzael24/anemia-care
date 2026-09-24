import { useState } from 'react';
import type { FormEvent } from 'react';
import { api } from './api';

interface Props {
  onLogin: (token: string) => void;
}

export default function LoginPage({ onLogin }: Props) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.login(username, password);
      onLogin(res.accessToken);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login gagal');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={submit}>
        <div className="login-logo">🩸</div>
        <h1>Anemia Care</h1>
        <p className="login-sub">Admin Monitoring — petugas/kader kesehatan</p>

        <label>
          Username
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>

        {error && <div className="error-box">{error}</div>}

        <button className="btn-primary" disabled={loading}>
          {loading ? 'Memproses…' : 'Masuk'}
        </button>

        <p className="login-hint">
          Kredensial default dev: <code>admin</code> / <code>admin123</code>
        </p>
      </form>
    </div>
  );
}