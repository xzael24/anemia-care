import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { MlResult, MlService } from './ml.service';
import { ScreeningStore } from './screening.store';

export interface ScreeningRecord {
  id: string;
  indication: 'anemia' | 'normal';
  confidence: number;
  hbEstimateGdl: number | null;
  source: 'ml' | 'mock';
  imageName: string;
  createdAt: string;
}

export const DISCLAIMER =
  'Hasil ini adalah indikasi awal skrining non-invasif, BUKAN diagnosis medis. ' +
  'Konsultasikan ke tenaga kesehatan untuk pemeriksaan darah (Hb) resmi.';

export const HISTORY_LIMIT = 100;

@Injectable()
export class ScreeningService {
  constructor(
    private readonly ml: MlService,
    private readonly store: ScreeningStore,
  ) {}

  async screen(file: Express.Multer.File): Promise<ScreeningRecord> {
    const result: MlResult = await this.ml.predict(file);
    const record: ScreeningRecord = {
      id: randomUUID(),
      indication: result.prediction.label,
      confidence: result.prediction.confidence,
      hbEstimateGdl: result.prediction.hbEstimateGdl,
      source: result.source,
      imageName: file.originalname || 'foto.jpg',
      createdAt: new Date().toISOString(),
    };
    await this.store.save(record);
    return record;
  }

  history(): Promise<ScreeningRecord[]> {
    return this.store.findRecent(HISTORY_LIMIT);
  }
}