import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';
import { JWT_EXPIRES_IN, JWT_SECRET } from '../auth/jwt.config';
import { JwtPayload } from '../auth/jwt-auth.guard';
import { ScreeningRecord } from '../screening/screening.service';
import { ScreeningStore } from '../screening/screening.store';
import { DaftarDto, LoginPasienDto } from './pasien.dto';
import { PasienRecord, PasienStore } from './pasien.store';

export interface PasienAuthResult {
  accessToken: string;
  expiresIn: string;
  pasien: Omit<PasienRecord, 'passwordHash'>;
}

@Injectable()
export class PasienService {
  constructor(
    private readonly store: PasienStore,
    private readonly screeningStore: ScreeningStore,
  ) {}

  /** Daftar akun pasien baru → token JWT (role 'pasien'). */
  async daftar(dto: DaftarDto): Promise<PasienAuthResult> {
    const username = dto.username.trim().toLowerCase();
    const existing = await this.store.findByUsername(username);
    if (existing) {
      throw new ConflictException('Username sudah terpakai');
    }

    const record: PasienRecord = {
      id: randomUUID(),
      username,
      nama: dto.nama.trim(),
      usia: dto.usia,
      gender: dto.gender,
      tipeKulit: dto.tipeKulit ?? null,
      hamil: dto.hamil ?? false,
      riwayatAnemia: dto.riwayatAnemia ?? false,
      createdAt: new Date().toISOString(),
      passwordHash: await bcrypt.hash(dto.password, 10),
    };
    await this.store.save(record);
    return this.token(record);
  }

  /** Login pasien → token JWT. */
  async login(dto: LoginPasienDto): Promise<PasienAuthResult> {
    const record = await this.store.findByUsername(
      (dto.username ?? '').trim().toLowerCase(),
    );
    const ok =
      record && (await bcrypt.compare(dto.password, record.passwordHash));
    if (!record || !ok) {
      throw new UnauthorizedException('Username atau password salah');
    }
    return this.token(record);
  }

  /** Profil akun dari token. */
  async me(pasienId: string): Promise<Omit<PasienRecord, 'passwordHash'>> {
    const record = await this.store.findById(pasienId);
    if (!record) {
      throw new NotFoundException('Akun tidak ditemukan');
    }
    const { passwordHash: _ph, ...pasien } = record;
    return pasien;
  }

  /** Riwayat skrining milik akun ini (batas 100). */
  async riwayat(pasienId: string): Promise<ScreeningRecord[]> {
    return this.screeningStore.findRecentByPasien(pasienId, 100);
  }

  private token(record: PasienRecord): PasienAuthResult {
    const payload: JwtPayload = {
      sub: record.id,
      username: record.username,
      role: 'pasien',
    };
    const accessToken = jwt.sign(payload, JWT_SECRET, {
      expiresIn: JWT_EXPIRES_IN,
    });
    const { passwordHash: _ph, ...pasien } = record;
    return { accessToken, expiresIn: JWT_EXPIRES_IN, pasien };
  }
}