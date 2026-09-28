import { Injectable } from '@nestjs/common';
import { Role } from '../../../common/types/auth-user';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { LoginListQueryDto, LoginStatus, loginStatusFlag } from './dto/login-account.dto';

export interface LoginAccount {
  id: string;
  employeeId: string | null;
  empCode: string;
  employeeName: string;
  username: string;
  role: Role;
  status: LoginStatus;
  lastLogin: string | null;
  isLocked: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface EligibleEmployee {
  id: string;
  empCode: string;
  fullName: string;
  employeeTypeName: string;
  mobile: string;
}

export interface LoginSaveParams {
  employeeId: number | null;
  username: string;
  passwordHash: string | null;
  role: Role;
  status: LoginStatus | undefined;
}

@Injectable()
export class LoginAccountRepository {
  constructor(private readonly db: DbService) {}

  async list(q: LoginListQueryDto): Promise<PagedData<LoginAccount>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_login_list', [
      searchOf(q),
      loginStatusFlag(q.status),
      filterValue(q.role),
      q.employeeId ?? null,
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<LoginAccount>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<LoginAccount> {
    const [rows] = await this.db.call<Row>('sp_login_get', [id]);
    return firstRow<LoginAccount>(rows)!;
  }

  async save(id: number, p: LoginSaveParams, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_login_save', [
      id,
      p.employeeId,
      p.username,
      p.passwordHash,
      p.role,
      loginStatusFlag(p.status) ?? 1,
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_login_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async eligibleEmployees(): Promise<EligibleEmployee[]> {
    const [rows] = await this.db.call<Row>('sp_login_eligible_employees');
    return mapRows<EligibleEmployee>(rows);
  }

  async resetPassword(id: number, hash: string, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_login_reset_password', [id, hash, userId]);
    return firstRow<WriteResult>(rows)!;
  }

  async block(id: number, blocked: boolean, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_login_block', [id, blocked ? 1 : 0, userId]);
    return firstRow<WriteResult>(rows)!;
  }
}
