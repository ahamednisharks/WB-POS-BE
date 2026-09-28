import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { EmployeeTypeListQueryDto, EmployeeTypeSaveDto } from './dto/employee-type.dto';
import { EmployeeType, EmployeeTypeOption, EmployeeTypeRepository } from './employee-type.repository';

@Injectable()
export class EmployeeTypeService {
  constructor(private readonly repo: EmployeeTypeRepository) {}

  async list(q: EmployeeTypeListQueryDto): Promise<ApiResult<EmployeeType[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<EmployeeType> {
    return this.repo.get(id);
  }

  async save(id: number, dto: EmployeeTypeSaveDto, userId: number): Promise<ApiResult<EmployeeType>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  dropdown(): Promise<EmployeeTypeOption[]> {
    return this.repo.dropdown();
  }
}
