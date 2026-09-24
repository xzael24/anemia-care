import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { DB_ENABLED, typeOrmRootModule } from './database';
import { DwModule } from './dw/dw.module';
import { FuzzyModule } from './fuzzy/fuzzy.module';
import { HealthModule } from './health/health.module';
import { PasienModule } from './pasien/pasien.module';
import { ScreeningModule } from './screening/screening.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    HealthModule,
    ScreeningModule,
    AuthModule,
    FuzzyModule,
    PasienModule,
    ...(DB_ENABLED && typeOrmRootModule ? [typeOrmRootModule] : []),
    // LAPISAN 3 — Data Warehouse (butuh Postgres).
    ...(DB_ENABLED ? [DwModule] : []),
  ],
})
export class AppModule {}