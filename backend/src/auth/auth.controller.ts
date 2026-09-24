import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthUser, JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('login')
  async login(@Body() body: { username?: string; password?: string }) {
    return this.auth.login(body.username ?? '', body.password ?? '');
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: { user: AuthUser }) {
    return req.user;
  }
}