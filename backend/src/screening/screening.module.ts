import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MlService } from './ml.service';
import { ScreeningController } from './screening.controller';
import { ScreeningEntity } from './screening.entity';
import { ScreeningService } from './screening.service';
import { InMemoryScreeningStore, ScreeningStore } from './screening.store';
import { TypeOrmScreeningStore } from './typeorm.store';

/** Aktifkan persistensi Postgres saat env DB_HOST di-set (compose/mandiri). */
const DB_ENABLED = !!process.env.DB_HOST;

const storeProvider = {
  provide: ScreeningStore,
  useClass: DB_ENABLED ? TypeOrmScreeningStore : InMemoryScreeningStore,
};

const typeOrmImports = DB_ENABLED
  ? [
      TypeOrmModule.forRoot({
        type: 'postgres',
        host: process.env.DB_HOST,
        port: Number(process.env.DB_PORT ?? 5432),
        username: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        autoLoadEntities: true,
        synchronize: true,
      }),
      TypeOrmModule.forFeature([ScreeningEntity]),
    ]
  : [];

@Module({
  imports: [...typeOrmImports],
  controllers: [ScreeningController],
  providers: [ScreeningService, MlService, storeProvider],
})
export class ScreeningModule {}