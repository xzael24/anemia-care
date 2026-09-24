import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { DwController } from './dw.controller';
import { DwService } from './dw.service';

/**
 * Lapisan 3 — Data Warehouse. Hanya terdaftar saat DB aktif (DB_HOST di-set).
 * DataSource disuntikkan dari TypeOrmCoreModule root (AppModule).
 */
@Module({
  imports: [AuthModule],
  controllers: [DwController],
  providers: [DwService],
})
export class DwModule {}