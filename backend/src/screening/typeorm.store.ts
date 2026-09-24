import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PasienEntity } from '../pasien/pasien.entity';
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
    const rows = await this.repo
      .createQueryBuilder('s')
      .leftJoinAndMapOne(
        's.pasien',
        PasienEntity,
        'p',
        'p.id = s."pasienId"',
      )
      .orderBy('s."createdAt"', 'DESC')
      .take(limit)
      .getMany();
    return rows.map((r) => this.mapRow(r));
  }

  async findRecentByPasien(
    pasienId: string,
    limit: number,
  ): Promise<ScreeningRecord[]> {
    const rows = await this.repo.find({
      where: { pasienId },
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
    const pasien = (r as ScreeningEntity & { pasien?: PasienEntity }).pasien;
    return {
      id: r.id,
      indication: r.indication,
      confidence: r.confidence,
      hbEstimateGdl: r.hbEstimateGdl,
      source: r.source,
      imageName: r.imageName,
      createdAt: r.createdAt.toISOString(),
      pasienId: r.pasienId,
      pasien: pasien
        ? { username: pasien.username, nama: pasien.nama }
        : null,
      status: r.status,
      verifiedBy: r.verifiedBy,
      verifiedAt: r.verifiedAt ? r.verifiedAt.toISOString() : null,
    };
  }
}