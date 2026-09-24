import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import * as bcrypt from 'bcryptjs';
import { Gender, TipeKulit } from './pasien.entity';

export interface Pasien {
  id: string;
  username: string;
  nama: string;
  usia: number;
  gender: Gender;
  tipeKulit: TipeKulit | null;
  hamil: boolean;
  riwayatAnemia: boolean;
  createdAt: string;
}

export interface PasienRecord extends Pasien {
  passwordHash: string;
}

export interface DaftarPasienInput {
  username: string;
  password: string;
  nama: string;
  usia: number;
  gender: Gender;
  tipeKulit?: TipeKulit;
  hamil?: boolean;
  riwayatAnemia?: boolean;
}

/**
 * Penyimpanan akun pasien pengguna mobile.
 * Implementasi: InMemoryPasienStore (tanpa DB, default/tests) atau
 * TypeOrmPasienStore (Postgres, aktif saat DB_HOST di-set) — pola sama
 * dengan PetugasStore.
 */
export abstract class PasienStore {
  abstract findByUsername(username: string): Promise<PasienRecord | null>;
  abstract findById(id: string): Promise<PasienRecord | null>;
  abstract save(record: PasienRecord): Promise<PasienRecord>;
}

@Injectable()
export class InMemoryPasienStore extends PasienStore {
  private readonly rows: PasienRecord[] = [];

  async findByUsername(username: string): Promise<PasienRecord | null> {
    return this.rows.find((r) => r.username === username) ?? null;
  }

  async findById(id: string): Promise<PasienRecord | null> {
    return this.rows.find((r) => r.id === id) ?? null;
  }

  async save(record: PasienRecord): Promise<PasienRecord> {
    this.rows.unshift(record);
    return record;
  }

  /** Helper untuk test/setup: membuat pasien lengkap dengan hash. */
  static build(input: DaftarPasienInput): PasienRecord {
    return {
      id: randomUUID(),
      username: input.username.trim(),
      nama: input.nama.trim(),
      usia: input.usia,
      gender: input.gender,
      tipeKulit: input.tipeKulit ?? null,
      hamil: input.hamil ?? false,
      riwayatAnemia: input.riwayatAnemia ?? false,
      createdAt: new Date().toISOString(),
      passwordHash: bcrypt.hashSync(input.password, 10),
    };
  }
}