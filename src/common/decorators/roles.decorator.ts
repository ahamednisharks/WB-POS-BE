import { applyDecorators, SetMetadata } from '@nestjs/common';
import { ApiBearerAuth, ApiForbiddenResponse, ApiUnauthorizedResponse } from '@nestjs/swagger';
import { Role } from '../types/auth-user';

export const ROLES_KEY = 'roles';

/** Allowed roles for a controller or route (method-level overrides class-level). Also documents it in Swagger. */
export const Roles = (...roles: Role[]): ClassDecorator & MethodDecorator =>
  applyDecorators(
    SetMetadata(ROLES_KEY, roles),
    ApiBearerAuth(),
    ApiUnauthorizedResponse({ description: 'Missing or expired token' }),
    ApiForbiddenResponse({ description: `Allowed roles: ${roles.join(', ')}` }),
  );
