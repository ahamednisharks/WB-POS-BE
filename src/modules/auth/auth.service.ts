import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AppConfig } from '../../config/configuration';
import { AuthUser, JwtPayload } from '../../common/types/auth-user';
import { WriteResult } from '../../common/utils/api-result';
import { AuthRepository, UserProfile } from './auth.repository';
import { ChangePasswordDto, LoginDto } from './dto/login.dto';

export const BCRYPT_ROUNDS = 10;

export interface LoginResponse {
  token: string;
  expiresIn: string;
  user: { id: string; name: string; role: string; username: string; employeeId: string | null };
}

@Injectable()
export class AuthService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly jwt: JwtService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  async login(dto: LoginDto): Promise<LoginResponse> {
    const creds = await this.repo.getUser(dto.username);
    // getUser raises 45401 for unknown users, so creds is always set here.
    const matches = creds ? await bcrypt.compare(dto.password, creds.passwordHash) : false;
    const profile = await this.repo.loginResult(Number(creds!.id), matches);
    const user = profile!;

    const jwtConfig = this.config.get('jwt', { infer: true });
    const expiresIn = dto.rememberMe ? jwtConfig.rememberExpires : jwtConfig.expires;
    const payload: JwtPayload = {
      sub: Number(user.id),
      username: user.username,
      role: user.role,
      employeeId: user.employeeId ? Number(user.employeeId) : null,
    };
    const token = await this.jwt.signAsync(payload, { expiresIn: expiresIn as never });
    return {
      token,
      expiresIn,
      user: { id: user.id, name: user.name, role: user.role, username: user.username, employeeId: user.employeeId },
    };
  }

  me(userId: number): Promise<UserProfile | null> {
    return this.repo.me(userId);
  }

  async changePassword(user: AuthUser, dto: ChangePasswordDto): Promise<WriteResult> {
    const hash = await this.repo.getHash(user.id);
    if (!hash || !(await bcrypt.compare(dto.currentPassword, hash))) {
      throw new BadRequestException({ message: 'Current password is incorrect', field: 'currentPassword' });
    }
    if (dto.currentPassword === dto.newPassword) {
      throw new BadRequestException({ message: 'New password must be different', field: 'newPassword' });
    }
    return this.repo.changePassword(user.id, await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS));
  }

  /** Used by the JWT strategy: the token is only valid while the user is still active. */
  async validateUser(payload: JwtPayload): Promise<AuthUser | null> {
    const profile = await this.repo.me(payload.sub).catch(() => null);
    if (!profile || !profile.isActive) return null;
    return {
      id: Number(profile.id),
      username: profile.username,
      role: profile.role,
      employeeId: profile.employeeId ? Number(profile.employeeId) : null,
      name: profile.name,
    };
  }
}
