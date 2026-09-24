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
  async screen(@UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('Foto wajib dikirim di field "photo"');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('File harus berupa gambar');
    }
    const record = await this.screenings.screen(file);
    return { ...record, disclaimer: DISCLAIMER };
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