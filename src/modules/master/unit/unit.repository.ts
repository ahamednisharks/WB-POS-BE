import { Injectable } from '@nestjs/common';
import { ListQueryDto } from '../../../common/dto/list-query.dto';
import { MasterStatus, statusFlag } from '../../../common/dto/status.dto';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { activeFlag, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { UnitSaveDto } from './dto/unit.dto';

export interface Unit {
  id: string;
  name: string;
  shortCode: string;
  allowDecimal: boolean;
  status: MasterStatus;
  itemCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface UnitOption {
  id: string;
  name: string;
  shortCode: string;
  allowDecimal: boolean;
}

@Injectable()
export class UnitRepository {
  constructor(private readonly db: DbService) {}

  async list(q: ListQueryDto): Promise<PagedData<Unit>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_unit_list', [searchOf(q), activeFlag(q.status), sortBy, sortDir, ...pageArgs(q)]);
    return { data: mapRows<Unit>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<Unit> {
    const [rows] = await this.db.call<Row>('sp_unit_get', [id]);
    return firstRow<Unit>(rows)!;
  }

  async save(id: number, dto: UnitSaveDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_unit_save', [
      id,
      dto.name,
      dto.shortCode,
      dto.allowDecimal ? 1 : 0,
      statusFlag(dto.status),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_unit_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(): Promise<UnitOption[]> {
    const [rows] = await this.db.call<Row>('sp_unit_dropdown');
    return mapRows<UnitOption>(rows);
  }
}
