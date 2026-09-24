import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthUser, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { DaftarDto, LoginPasienDto } from './pasien.dto';
import { PasienService } from './pasien.service';

/**
 * Akun pengguna mobile (Tahap 3) — daftar/login → JWT role `pasien`,
 * profil, dan riwayat skrining milik akun. Berbeda dengan `AuthModule`
 * yang khusus petugas/admin (web).
 */
@Controller('pasien')
export class PasienController {
  constructor(private readonly pasien: PasienService) {}

  @Post('daftar')
  daftar(@Body() dto: DaftarDto) {
    return this.pasien.daftar(dto);
  }

  @Post('login')
  login(@Body() dto: LoginPasienDto) {
    return this.pasien.login(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('pasien')
  me(@Req() req: { user: AuthUser }) {
    return this.pasien.me(req.user.id);
  }

  @Get('me/skrining')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('pasien')
  riwayat(@Req() req: { user: AuthUser }) {
    return this.pasien.riwayat(req.user.id);
  }
}
