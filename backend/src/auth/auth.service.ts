import { Injectable, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';
import { JWT_EXPIRES_IN, JWT_SECRET } from './jwt.config';
import { JwtPayload } from './jwt-auth.guard';
import { Petugas, PetugasStore } from './petugas.store';

export interface LoginResult {
  accessToken: string;
  expiresIn: string;
  petugas: Petugas;
}

@Injectable()
export class AuthService {
  constructor(private readonly store: PetugasStore) {}

  async login(username: string, password: string): Promise<LoginResult> {
    const record = await this.store.findByUsername(username?.trim() ?? '');
    const passwordOk =
      record && (await bcrypt.compare(password ?? '', record.passwordHash));
    if (!record || !passwordOk) {
      throw new UnauthorizedException('Username atau password salah');
    }

    const payload: JwtPayload = {
      sub: record.id,
      username: record.username,
      role: record.role,
    };
    const accessToken = jwt.sign(payload, JWT_SECRET, {
      expiresIn: JWT_EXPIRES_IN,
    });
    const { passwordHash: _ignored, ...petugas } = record;
    return { accessToken, expiresIn: JWT_EXPIRES_IN, petugas };
  }
}