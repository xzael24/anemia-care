import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import * as bcrypt from 'bcryptjs';

export interface Petugas {
  id: string;
  username: string;
  name: string;
  role: 'admin' | 'petugas';
}

export interface PetugasRecord extends Petugas {
  passwordHash: string;
}

/**
 * Penyimpanan akun petugas/admin.
 * Implementasi: InMemoryPetugasStore (tanpa DB, default/tests) atau
 * TypeOrmPetugasStore (Postgres, aktif saat DB_HOST di-set).
 */
export abstract class PetugasStore {
  abstract findByUsername(username: string): Promise<PetugasRecord | null>;
}

export const DEFAULT_ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
export const DEFAULT_ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

@Injectable()
export class InMemoryPetugasStore extends PetugasStore {
  private readonly rows: PetugasRecord[];

  constructor() {
    super();
    this.rows = [
      {
        id: randomUUID(),
        username: DEFAULT_ADMIN_USERNAME,
        name: 'Administrator',
        role: 'admin',
        passwordHash: bcrypt.hashSync(DEFAULT_ADMIN_PASSWORD, 10),
      },
    ];
  }

  async findByUsername(username: string): Promise<PetugasRecord | null> {
    return this.rows.find((r) => r.username === username) ?? null;
  }
}