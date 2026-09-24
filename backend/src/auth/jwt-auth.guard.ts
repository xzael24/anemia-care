import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import * as jwt from 'jsonwebtoken';
import { JWT_SECRET } from './jwt.config';

export interface AuthUser {
  id: string;
  username: string;
  role: string;
}

export interface JwtPayload {
  sub: string;
  username: string;
  role: string;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();
    const token = this.extractToken(req);
    if (!token) {
      throw new UnauthorizedException('Token tidak ditemukan');
    }
    try {
      const payload = jwt.verify(token, JWT_SECRET) as jwt.JwtPayload &
        JwtPayload;
      req.user = {
        id: payload.sub,
        username: payload.username,
        role: payload.role,
      };
      return true;
    } catch {
      throw new UnauthorizedException('Token tidak valid atau kadaluarsa');
    }
  }

  private extractToken(req: Request): string | undefined {
    const [type, token] = req.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}