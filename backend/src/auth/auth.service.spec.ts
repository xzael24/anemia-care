import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { InMemoryPetugasStore } from './petugas.store';

function makeService(): AuthService {
  return new AuthService(new InMemoryPetugasStore());
}

describe('AuthService', () => {
  it('login admin/admin123 -> accessToken + petugas admin', async () => {
    const res = await makeService().login('admin', 'admin123');
    expect(res.accessToken).toEqual(expect.any(String));
    expect(res.expiresIn).toBe('8h');
    expect(res.petugas).toMatchObject({ username: 'admin', role: 'admin' });
    expect(res.petugas).not.toHaveProperty('passwordHash');
  });

  it('password salah -> UnauthorizedException', async () => {
    await expect(makeService().login('admin', 'salah')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('username tidak dikenal -> UnauthorizedException', async () => {
    await expect(makeService().login('nobody', 'x')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});