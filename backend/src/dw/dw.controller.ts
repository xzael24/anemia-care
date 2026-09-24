import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AuthUser, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { DwService, DwSummary, DwTrendPoint } from './dw.service';

/**
 * API dashboard agregat (LAPISAN 3 — Data Warehouse).
 * Tanpa DB (mode test in-memory), DwModule tidak terdaftar → 404.
 */
@Controller('dashboard')
export class DwController {
  constructor(private readonly dw: DwService) {}

  @Get('summary')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'petugas')
  summary(): Promise<DwSummary> {
    return this.dw.summary();
  }

  @Get('trend')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'petugas')
  trend(@Query('days') days?: string): Promise<DwTrendPoint[]> {
    const parsed = Number(days);
    return this.dw.trend(Number.isFinite(parsed) ? parsed : 30);
  }
}