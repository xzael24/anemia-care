import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthUser } from './jwt-auth.guard';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles || roles.length === 0) {
      return true;
    }
    const user = context.switchToHttp().getRequest<{ user?: AuthUser }>().user;
    if (!user || !roles.includes(user.role)) {
      throw new ForbiddenException('Akses ditolak: role tidak diizinkan');
    }
    return true;
  }
}