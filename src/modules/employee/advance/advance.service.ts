import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { Advance, AdvanceRepository, PendingAdvance } from './advance.repository';
import { AdvanceListQueryDto, AdvanceSaveDto } from './dto/advance.dto';

@Injectable()
export class AdvanceService {
  constructor(private readonly repo: AdvanceRepository) {}

  async list(q: AdvanceListQueryDto): Promise<ApiResult<Advance[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<Advance> {
    return this.repo.get(id);
  }

  async save(id: number, dto: AdvanceSaveDto, userId: number): Promise<ApiResult<Advance>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  pending(employeeId: number): Promise<PendingAdvance> {
    return this.repo.pending(employeeId);
  }
}
