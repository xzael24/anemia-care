import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DB_ENABLED } from '../database';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PetugasEntity } from './petugas.entity';
import { InMemoryPetugasStore, PetugasStore } from './petugas.store';
import { RolesGuard } from './roles.guard';
import { TypeOrmPetugasStore } from './typeorm.petugas.store';

@Module({
  imports: [
    ...(DB_ENABLED ? [TypeOrmModule.forFeature([PetugasEntity])] : []),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    {
      provide: PetugasStore,
      useClass: DB_ENABLED ? TypeOrmPetugasStore : InMemoryPetugasStore,
    },
    JwtAuthGuard,
    RolesGuard,
  ],
  exports: [JwtAuthGuard, RolesGuard],
})
export class AuthModule {}