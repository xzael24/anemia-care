import {
  BadRequestException,
  Controller,
  Get,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
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
}