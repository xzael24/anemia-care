import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import * as bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { PetugasEntity } from './petugas.entity';
import {
  DEFAULT_ADMIN_PASSWORD,
  DEFAULT_ADMIN_USERNAME,
  PetugasRecord,
  PetugasStore,
} from './petugas.store';

@Injectable()
export class TypeOrmPetugasStore extends PetugasStore implements OnModuleInit {
  constructor(
    @InjectRepository(PetugasEntity)
    private readonly repo: Repository<PetugasEntity>,
  ) {
    super();
  }

  /** Seed admin default (sekali, saat tabel masih kosong). */
  async onModuleInit(): Promise<void> {
    const existing = await this.repo.findOne({
      where: { username: DEFAULT_ADMIN_USERNAME },
    });
    if (!existing) {
      await this.repo.save(
        this.repo.create({
          id: randomUUID(),
          username: DEFAULT_ADMIN_USERNAME,
          name: 'Administrator',
          role: 'admin',
          passwordHash: await bcrypt.hash(DEFAULT_ADMIN_PASSWORD, 10),
        }),
      );
    }
  }

  async findByUsername(username: string): Promise<PetugasRecord | null> {
    const row = await this.repo.findOne({ where: { username } });
    if (!row) {
      return null;
    }
    return {
      id: row.id,
      username: row.username,
      name: row.name,
      role: row.role,
      passwordHash: row.passwordHash,
    };
  }
}