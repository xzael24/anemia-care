import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PasienEntity } from './pasien.entity';
import { PasienRecord, PasienStore } from './pasien.store';

@Injectable()
export class TypeOrmPasienStore extends PasienStore {
  constructor(
    @InjectRepository(PasienEntity)
    private readonly repo: Repository<PasienEntity>,
  ) {
    super();
  }

  async findByUsername(username: string): Promise<PasienRecord | null> {
    const row = await this.repo.findOne({ where: { username } });
    return row ? this.mapRow(row) : null;
  }

  async findById(id: string): Promise<PasienRecord | null> {
    const row = await this.repo.findOne({ where: { id } });
    return row ? this.mapRow(row) : null;
  }

  async save(record: PasienRecord): Promise<PasienRecord> {
    const entity = this.repo.create({
      ...record,
      createdAt: new Date(record.createdAt),
    });
    await this.repo.save(entity);
    return record;
  }

  private mapRow(r: PasienEntity): PasienRecord {
    return {
      id: r.id,
      username: r.username,
      nama: r.nama,
      usia: r.usia,
      gender: r.gender,
      tipeKulit: r.tipeKulit,
      hamil: r.hamil,
      riwayatAnemia: r.riwayatAnemia,
      createdAt: r.createdAt.toISOString(),
      passwordHash: r.passwordHash,
    };
  }
}