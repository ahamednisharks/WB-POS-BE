import { Injectable } from '@nestjs/common';
import { MasterStatus, statusFlag } from '../../../common/dto/status.dto';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { activeFlag, boolFlag, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { EmployeeTypeListQueryDto, EmployeeTypeSaveDto } from './dto/employee-type.dto';

export interface EmployeeType {
  id: string;
  name: string;
  description: string;
  canLogin: boolean;
  status: MasterStatus;
  employeeCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface EmployeeTypeOption {
  id: string;
  name: string;
  canLogin: boolean;
}

@Injectable()
export class EmployeeTypeRepository {
  constructor(private readonly db: DbService) {}

  async list(q: EmployeeTypeListQueryDto): Promise<PagedData<EmployeeType>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_employee_type_list', [
      searchOf(q),
      activeFlag(q.status),
      boolFlag(q.canLogin),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<EmployeeType>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<EmployeeType> {
    const [rows] = await this.db.call<Row>('sp_employee_type_get', [id]);
    return firstRow<EmployeeType>(rows)!;
  }

  async save(id: number, dto: EmployeeTypeSaveDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_employee_type_save', [
      id,
      dto.name,
      dto.description ?? null,
      dto.canLogin ? 1 : 0,
      statusFlag(dto.status),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_employee_type_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(): Promise<EmployeeTypeOption[]> {
    const [rows] = await this.db.call<Row>('sp_employee_type_dropdown');
    return mapRows<EmployeeTypeOption>(rows);
  }
}
