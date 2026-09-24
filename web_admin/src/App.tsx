import { useState } from 'react';
import { clearToken, getToken, setToken } from './api';
import LoginPage from './LoginPage';
import DashboardPage from './DashboardPage';

export default function App() {
  const [session, setSession] = useState<string | null>(getToken());

  if (!session) {
    return (
      <LoginPage
        onLogin={(token: string) => {
          setToken(token);
          setSession(token);
        }}
      />
    );
  }

  return (
    <DashboardPage
      onLogout={() => {
        clearToken();
        setSession(null);
      }}
    />
  );
}