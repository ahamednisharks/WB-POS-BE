import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { BCRYPT_ROUNDS } from '../../auth/auth.service';
import { LoginCreateDto, LoginListQueryDto, LoginUpdateDto } from './dto/login-account.dto';
import { EligibleEmployee, LoginAccount, LoginAccountRepository } from './login-account.repository';

/** Passwords are hashed here; the SPs only ever receive bcrypt hashes. */
@Injectable()
export class LoginAccountService {
  constructor(private readonly repo: LoginAccountRepository) {}

  async list(q: LoginListQueryDto): Promise<ApiResult<LoginAccount[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<LoginAccount> {
    return this.repo.get(id);
  }

  async create(dto: LoginCreateDto, userId: number): Promise<ApiResult<LoginAccount>> {
    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const res = await this.repo.save(0, { employeeId: dto.employeeId, username: dto.username, passwordHash, role: dto.role, status: dto.status }, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async update(id: number, dto: LoginUpdateDto, userId: number): Promise<ApiResult<LoginAccount>> {
    const res = await this.repo.save(id, { employeeId: null, username: dto.username, passwordHash: null, role: dto.role, status: dto.status }, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  eligibleEmployees(): Promise<EligibleEmployee[]> {
    return this.repo.eligibleEmployees();
  }

  async resetPassword(id: number, password: string, userId: number): Promise<ApiResult<{ message: string }>> {
    const res = await this.repo.resetPassword(id, await bcrypt.hash(password, BCRYPT_ROUNDS), userId);
    return ok({ message: res.message }, res.message);
  }

  async block(id: number, blocked: boolean, userId: number): Promise<ApiResult<LoginAccount>> {
    const res = await this.repo.block(id, blocked, userId);
    return ok(await this.repo.get(id), res.message);
  }
}
