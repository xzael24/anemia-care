import { Injectable } from '@nestjs/common';
import { ScreeningRecord } from './screening.service';

/**
 * Penyimpanan riwayat skrining.
 * Implementasi: InMemoryScreeningStore (tanpa DB, default) atau
 * TypeOrmScreeningStore (Postgres, aktif saat DB_HOST di-set).
 */
export abstract class ScreeningStore {
  abstract save(record: ScreeningRecord): Promise<ScreeningRecord>;
  abstract findRecent(limit: number): Promise<ScreeningRecord[]>;
}

@Injectable()
export class InMemoryScreeningStore extends ScreeningStore {
  private readonly records: ScreeningRecord[] = [];

  async save(record: ScreeningRecord): Promise<ScreeningRecord> {
    this.records.unshift(record);
    return record;
  }

  async findRecent(limit: number): Promise<ScreeningRecord[]> {
    return this.records.slice(0, limit);
  }
}