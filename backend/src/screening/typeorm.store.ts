import { Injectable } from '@nestjs/common';
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
    });
    await this.repo.save(entity);
    return record;
  }

  async findRecent(limit: number): Promise<ScreeningRecord[]> {
    const rows = await this.repo.find({
      order: { createdAt: 'DESC' },
      take: limit,
    });
    return rows.map((r) => ({
      id: r.id,
      indication: r.indication,
      confidence: r.confidence,
      hbEstimateGdl: r.hbEstimateGdl,
      source: r.source,
      imageName: r.imageName,
      createdAt: r.createdAt.toISOString(),
    }));
  }
}