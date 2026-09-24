import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { DB_ENABLED } from '../database';
import { ScreeningModule } from '../screening/screening.module';
import { PasienController } from './pasien.controller';
import { PasienEntity } from './pasien.entity';
import { PasienService } from './pasien.service';
import { InMemoryPasienStore, PasienStore } from './pasien.store';
import { TypeOrmPasienStore } from './typeorm.pasien.store';

/** Akun pengguna mobile — daftar/login, profil, riwayat per akun. */
@Module({
  imports: [
    AuthModule,
    ScreeningModule, // ScreeningStore (riwayat per akun)
    ...(DB_ENABLED ? [TypeOrmModule.forFeature([PasienEntity])] : []),
  ],
  controllers: [PasienController],
  providers: [
    PasienService,
    {
      provide: PasienStore,
      useClass: DB_ENABLED ? TypeOrmPasienStore : InMemoryPasienStore,
    },
  ],
})
export class PasienModule {}