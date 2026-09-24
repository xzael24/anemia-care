import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { DB_ENABLED } from '../database';
import { MlService } from './ml.service';
import { ScreeningController } from './screening.controller';
import { ScreeningEntity } from './screening.entity';
import { ScreeningService } from './screening.service';
import { InMemoryScreeningStore, ScreeningStore } from './screening.store';
import { TypeOrmScreeningStore } from './typeorm.store';

const storeProvider = {
  provide: ScreeningStore,
  useClass: DB_ENABLED ? TypeOrmScreeningStore : InMemoryScreeningStore,
};

@Module({
  imports: [
    AuthModule,
    ...(DB_ENABLED ? [TypeOrmModule.forFeature([ScreeningEntity])] : []),
  ],
  controllers: [ScreeningController],
  providers: [ScreeningService, MlService, storeProvider],
})
export class ScreeningModule {}