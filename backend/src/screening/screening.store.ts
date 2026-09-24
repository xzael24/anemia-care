import { Injectable, NotFoundException } from '@nestjs/common';
import { ScreeningRecord } from './screening.service';

/**
 * Penyimpanan riwayat skrining.
 * Implementasi: InMemoryScreeningStore (tanpa DB, default) atau
 * TypeOrmScreeningStore (Postgres, aktif saat DB_HOST di-set).
 */
export abstract class ScreeningStore {
  abstract save(record: ScreeningRecord): Promise<ScreeningRecord>;
  abstract findRecent(limit: number): Promise<ScreeningRecord[]>;
  abstract findRecentByPasien(
    pasienId: string,
    limit: number,
  ): Promise<ScreeningRecord[]>;
  abstract verify(id: string, username: string): Promise<ScreeningRecord>;
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

  async findRecentByPasien(
    pasienId: string,
    limit: number,
  ): Promise<ScreeningRecord[]> {
    return this.records.filter((r) => r.pasienId === pasienId).slice(0, limit);
  }

  async verify(id: string, username: string): Promise<ScreeningRecord> {
    const record = this.records.find((r) => r.id === id);
    if (!record) {
      throw new NotFoundException(`Skrining ${id} tidak ditemukan`);
    }
    record.status = 'terverifikasi';
    record.verifiedBy = username;
    record.verifiedAt = new Date().toISOString();
    return { ...record };
  }
}