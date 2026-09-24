import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { DB_ENABLED, typeOrmRootModule } from './database';
import { HealthModule } from './health/health.module';
import { ScreeningModule } from './screening/screening.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    HealthModule,
    ScreeningModule,
    AuthModule,
    ...(DB_ENABLED && typeOrmRootModule ? [typeOrmRootModule] : []),
  ],
})
export class AppModule {}