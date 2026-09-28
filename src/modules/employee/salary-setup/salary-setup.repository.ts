import { Injectable } from '@nestjs/common';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { SalarySetupListQueryDto, SalarySetupSaveDto, SalaryType } from './dto/salary-setup.dto';

export interface SalarySetup {
  id: string;
  employeeId: string;
  empCode: string;
  employeeName: string;
  salaryType: SalaryType;
  basicSalary: number;
  allowances: number;
  effectiveFrom: string;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class SalarySetupRepository {
  constructor(private readonly db: DbService) {}

  async list(q: SalarySetupListQueryDto): Promise<PagedData<SalarySetup>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_salary_setup_list', [
      searchOf(q),
      q.employeeId ?? null,
      filterValue(q.salaryType),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<SalarySetup>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<SalarySetup> {
    const [rows] = await this.db.call<Row>('sp_salary_setup_get', [id]);
    return firstRow<SalarySetup>(rows)!;
  }

  async save(id: number, dto: SalarySetupSaveDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_salary_setup_save', [
      id,
      dto.employeeId,
      dto.salaryType,
      dto.basicSalary,
      dto.allowances ?? 0,
      dto.effectiveFrom,
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_salary_setup_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async current(employeeId: number, month: string | null): Promise<(SalarySetup & { month: string }) | null> {
    const [rows] = await this.db.call<Row>('sp_salary_setup_current', [employeeId, month]);
    return firstRow(rows);
  }
}
