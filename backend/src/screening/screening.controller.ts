import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import * as jwt from 'jsonwebtoken';
import { JWT_SECRET } from '../auth/jwt.config';
import { AuthUser, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import {
  DISCLAIMER,
  ScreeningRecord,
  ScreeningService,
} from './screening.service';

@Controller('screening')
export class ScreeningController {
  constructor(private readonly screenings: ScreeningService) {}

  @Post()
  @UseInterceptors(FileInterceptor('photo'))
  async screen(
    @UploadedFile() file?: Express.Multer.File,
    @Req() req?: Request,
  ) {
    if (!file) {
      throw new BadRequestException('Foto wajib dikirim di field "photo"');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('File harus berupa gambar');
    }
    // Opsional: bila token pasien valid → skrining tercatat ke akun.
    // Token invalid/absen/petugas → tetap boleh anonim (publik).
    const pasienId = this.pasienIdDariToken(req);
    const record = await this.screenings.screen(file, pasienId);
    return { ...record, disclaimer: DISCLAIMER };
  }

  /** Baca Authorization: Bearer <jwt>; kembalikan sub hanya untuk role pasien. */
  private pasienIdDariToken(req?: Request): string | null {
    const [type, token] = req?.headers?.authorization?.split(' ') ?? [];
    if (type !== 'Bearer' || !token) {
      return null;
    }
    try {
      const payload = jwt.verify(token, JWT_SECRET) as jwt.JwtPayload & {
        role?: string;
      };
      return payload.role === 'pasien' ? (payload.sub ?? null) : null;
    } catch {
      return null;
    }
  }

  /** Riwayat skrining = area petugas/admin (login dulu). */
  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'petugas')
  async history(): Promise<ScreeningRecord[]> {
    return this.screenings.history();
  }

  /** Verifikasi hasil oleh petugas (human-in-the-loop). */
  @Patch(':id/verify')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'petugas')
  async verify(
    @Param('id') id: string,
    @Req() req: { user: AuthUser },
  ) {
    const record = await this.screenings.verify(id, req.user.username);
    return { ...record, disclaimer: DISCLAIMER };
  }
}