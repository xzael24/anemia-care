import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ScreeningEntity } from './screening.entity';
import { ScreeningRecord } from './screening.service';
import { ScreeningStore } from './screening.store';

@Injectable()
export class TypeOrmScreeningStore extends ScreeningStore {
  constructor(
    @InjectRepository(ScreeningEntity)
    private readonly repo: Repository<ScreeningEntity>,
  ) {
    super();
  }

  async save(record: ScreeningRecord): Promise<ScreeningRecord> {
    const entity = this.repo.create({
      ...record,
      createdAt: new Date(record.createdAt),
      verifiedAt: record.verifiedAt ? new Date(record.verifiedAt) : null,
    });
    await this.repo.save(entity);
    return record;
  }

  async findRecent(limit: number): Promise<ScreeningRecord[]> {
    const rows = await this.repo.find({
      order: { createdAt: 'DESC' },
      take: limit,
    });
    return rows.map((r) => this.mapRow(r));
  }

  async verify(id: string, username: string): Promise<ScreeningRecord> {
    const row = await this.repo.findOne({ where: { id } });
    if (!row) {
      throw new NotFoundException(`Skrining ${id} tidak ditemukan`);
    }
    row.status = 'terverifikasi';
    row.verifiedBy = username;
    row.verifiedAt = new Date();
    await this.repo.save(row);
    return this.mapRow(row);
  }

  private mapRow(r: ScreeningEntity): ScreeningRecord {
    return {
      id: r.id,
      indication: r.indication,
      confidence: r.confidence,
      hbEstimateGdl: r.hbEstimateGdl,
      source: r.source,
      imageName: r.imageName,
      createdAt: r.createdAt.toISOString(),
      status: r.status,
      verifiedBy: r.verifiedBy,
      verifiedAt: r.verifiedAt ? r.verifiedAt.toISOString() : null,
    };
  }
}