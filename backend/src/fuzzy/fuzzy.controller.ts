import { Body, Controller, Get, Post } from '@nestjs/common';
import { RekomendasiDto } from './fuzzy.dto';
import { FuzzyService } from './fuzzy.service';
import type { RekomendasiHasil } from './fuzzy.service';

/**
 * Fuzzy rekomendasi (PSC1) — endpoint publik: mobile mengirim hasil visual ML
 * + konteks singkat (gejala/risiko/tipe kulit) → rekomendasi tindak lanjut.
 */
@Controller('rekomendasi')
export class FuzzyController {
  constructor(private readonly fuzzy: FuzzyService) {}

  @Post()
  rekomendasi(@Body() dto: RekomendasiDto): RekomendasiHasil {
    return this.fuzzy.rekomendasi(dto);
  }

  /** Tabel rule fuzzy — dokumentasi diri (bahan laporan PSC1). */
  @Get('aturan')
  aturan() {
    return { input: ['visual', 'gejala', 'risiko'], rules: this.fuzzy.aturan() };
  }
}