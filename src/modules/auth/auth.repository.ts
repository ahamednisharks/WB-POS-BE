import { Injectable } from '@nestjs/common';
import { DbService } from '../../database/db.service';
import { WriteResult } from '../../common/utils/api-result';
import { firstRow, Row } from '../../common/utils/to-camel';
import { Role } from '../../common/types/auth-user';

export interface UserCredentials {
  id: string;
  username: string;
  passwordHash: string;
  role: Role;
  status: number;
  employeeId: string | null;
}

export interface UserProfile {
  id: string;
  username: string;
  name: string;
  role: Role;
  employeeId: string | null;
  empCode: string | null;
  lastLoginAt: string | null;
  isActive: boolean;
}

@Injectable()
export class AuthRepository {
  constructor(private readonly db: DbService) {}

  async getUser(username: string): Promise<UserCredentials | null> {
    const [rows] = await this.db.call<Row>('sp_auth_get_user', [username]);
    return firstRow<UserCredentials>(rows);
  }

  async loginResult(userId: number, success: boolean): Promise<UserProfile | null> {
    const [rows] = await this.db.call<Row>('sp_auth_login_result', [userId, success ? 1 : 0]);
    return firstRow<UserProfile>(rows);
  }

  async me(userId: number): Promise<UserProfile | null> {
    const [rows] = await this.db.call<Row>('sp_auth_me', [userId]);
    return firstRow<UserProfile>(rows);
  }

  async getHash(userId: number): Promise<string | null> {
    const [rows] = await this.db.call<Row>('sp_auth_get_hash', [userId]);
    return firstRow<{ passwordHash: string }>(rows)?.passwordHash ?? null;
  }

  async changePassword(userId: number, hash: string): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_auth_change_password', [userId, hash]);
    return firstRow<WriteResult>(rows)!;
  }
}
