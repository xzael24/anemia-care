import { ConflictException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ScreeningRecord } from '../screening/screening.service';
import { ScreeningStore } from '../screening/screening.store';
import { PasienService } from './pasien.service';
import { InMemoryPasienStore, PasienStore } from './pasien.store';

class FakeScreeningStore extends ScreeningStore {
  rows: ScreeningRecord[] = [];

  async save(r: ScreeningRecord): Promise<ScreeningRecord> {
    this.rows.unshift(r);
    return r;
  }

  async findRecent(limit: number): Promise<ScreeningRecord[]> {
    return this.rows.slice(0, limit);
  }

  async findRecentByPasien(
    pasienId: string,
    limit: number,
  ): Promise<ScreeningRecord[]> {
    return this.rows.filter((r) => r.pasienId === pasienId).slice(0, limit);
  }

  async verify(id: string, username: string): Promise<ScreeningRecord> {
    const r = this.rows.find((x) => x.id === id);
    if (!r) throw new NotFoundException();
    return { ...r, status: 'terverifikasi', verifiedBy: username };
  }
}

function setup(): { svc: PasienService; screening: FakeScreeningStore } {
  const screening = new FakeScreeningStore();
  const svc = new PasienService(new InMemoryPasienStore(), screening);
  return { svc, screening };
}

const DTO = {
  username: 'SARI_23',
  password: 'rahasia123',
  nama: 'Sari Amalia',
  usia: 24,
  gender: 'perempuan' as const,
  tipeKulit: 'sedang' as const,
  hamil: true,
  riwayatAnemia: true,
};

describe('PasienService (akun pengguna mobile)', () => {
  it('daftar → token + profil (tanpa passwordHash), username dinormalisasi', async () => {
    const { svc } = setup();
    const r = await svc.daftar(DTO);
    expect(r.accessToken).toBeDefined();
    expect(r.pasien.username).toBe('sari_23');
    expect(r.pasien.nama).toBe('Sari Amalia');
    expect(r.pasien.usia).toBe(24);
    expect(r.pasien.gender).toBe('perempuan');
    expect(r.pasien.hamil).toBe(true);
    expect(r.pasien.tipeKulit).toBe('sedang');
    expect((r.pasien as Record<string, unknown>).passwordHash).toBeUndefined();
  });

  it('daftar username duplikat → 409 Conflict', async () => {
    const { svc } = setup();
    await svc.daftar(DTO);
    await expect(svc.daftar({ ...DTO, username: 'sari_23' })).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  it('login benar → token; password salah → 401', async () => {
    const { svc } = setup();
    await svc.daftar(DTO);
    const ok = await svc.login({ username: 'SARI_23', password: 'rahasia123' });
    expect(ok.pasien.username).toBe('sari_23');
    expect(ok.accessToken).toBeDefined();
    await expect(
      svc.login({ username: 'sari_23', password: 'salah' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('me: profil ada; akun tak dikenal → 404', async () => {
    const { svc } = setup();
    const r = await svc.daftar(DTO);
    const me = await svc.me(r.pasien.id);
    expect(me.riwayatAnemia).toBe(true);
    await expect(svc.me('tidak-ada')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('riwayat hanya mengembalikan skrining milik akun itu', async () => {
    const { svc, screening } = setup();
    const r = await svc.daftar(DTO);
    screening.rows = [
      { id: 'a1', pasienId: r.pasien.id } as ScreeningRecord,
      { id: 'a2', pasienId: r.pasien.id } as ScreeningRecord,
      { id: 'b1', pasienId: 'lain' } as ScreeningRecord,
    ];
    const list = await svc.riwayat(r.pasien.id);
    expect(list.map((x) => x.id)).toEqual(['a1', 'a2']);
  });
});