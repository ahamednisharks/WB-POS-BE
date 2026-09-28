import { Injectable } from '@nestjs/common';
import { ListQueryDto } from '../../../common/dto/list-query.dto';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { UnitSaveDto } from './dto/unit.dto';
import { Unit, UnitOption, UnitRepository } from './unit.repository';

@Injectable()
export class UnitService {
  constructor(private readonly repo: UnitRepository) {}

  async list(q: ListQueryDto): Promise<ApiResult<Unit[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<Unit> {
    return this.repo.get(id);
  }

  async save(id: number, dto: UnitSaveDto, userId: number): Promise<ApiResult<Unit>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  dropdown(): Promise<UnitOption[]> {
    return this.repo.dropdown();
  }
}
