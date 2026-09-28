import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { SalarySetupListQueryDto, SalarySetupSaveDto } from './dto/salary-setup.dto';
import { SalarySetup, SalarySetupRepository } from './salary-setup.repository';

@Injectable()
export class SalarySetupService {
  constructor(private readonly repo: SalarySetupRepository) {}

  async list(q: SalarySetupListQueryDto): Promise<ApiResult<SalarySetup[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<SalarySetup> {
    return this.repo.get(id);
  }

  async save(id: number, dto: SalarySetupSaveDto, userId: number): Promise<ApiResult<SalarySetup>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  current(employeeId: number, month?: string): Promise<(SalarySetup & { month: string }) | null> {
    return this.repo.current(employeeId, month ?? null);
  }
}
