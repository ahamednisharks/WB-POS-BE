import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, ok, paged } from '../../../common/utils/api-result';
import { DayClose, DayClosePreview, DayCloseRepository } from './day-close.repository';
import { DayCloseListQueryDto, DayCloseSaveDto } from './dto/day-close.dto';

@Injectable()
export class DayCloseService {
  constructor(private readonly repo: DayCloseRepository) {}

  preview(date: string | undefined, user: AuthUser): Promise<DayClosePreview> {
    return this.repo.preview(date ?? null, user);
  }

  async save(dto: DayCloseSaveDto, user: AuthUser): Promise<ApiResult<DayClose>> {
    const res = await this.repo.save(dto, user);
    return ok(await this.repo.get(Number(res.id), user), res.message);
  }

  get(id: number, user: AuthUser): Promise<DayClose> {
    return this.repo.get(id, user);
  }

  async list(q: DayCloseListQueryDto): Promise<ApiResult<DayClose[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }
}
