import { Module } from '@nestjs/common';
import { FuzzyController } from './fuzzy.controller';
import { FuzzyService } from './fuzzy.service';

/** Fuzzy rekomendasi (PSC1) — tidak butuh DB, selalu terdaftar. */
@Module({
  controllers: [FuzzyController],
  providers: [FuzzyService],
})
export class FuzzyModule {}