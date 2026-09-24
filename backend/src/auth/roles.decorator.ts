import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/** Batasi akses route ke role tertentu: @Roles('admin', 'petugas') */
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);