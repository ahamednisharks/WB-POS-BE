import { Injectable } from '@nestjs/common';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { boolFlag, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { AdvanceListQueryDto, AdvanceSaveDto } from './dto/advance.dto';

export interface Advance {
  id: string;
  employeeId: string;
  empCode: string;
  employeeName: string;
  advanceDate: string;
  amount: number;
  recoveredAmount: number;
  balance: number;
  remarks: string;
  createdAt: string;
  updatedAt: string;
}

export interface PendingAdvance {
  employeeId: string;
  totalAdvance: number;
  totalRecovered: number;
  pending: number;
  advances: Row[];
}

@Injectable()
export class AdvanceRepository {
  constructor(private readonly db: DbService) {}

  async list(q: AdvanceListQueryDto): Promise<PagedData<Advance>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_advance_list', [
      searchOf(q),
      q.employeeId ?? null,
      q.from ?? null,
      q.to ?? null,
      boolFlag(q.pendingOnly),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<Advance>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<Advance> {
    const [rows] = await this.db.call<Row>('sp_advance_get', [id]);
    return firstRow<Advance>(rows)!;
  }

  async save(id: number, dto: AdvanceSaveDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_advance_save', [id, dto.employeeId, dto.advanceDate, dto.amount, dto.remarks ?? null, userId]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_advance_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async pending(employeeId: number): Promise<PendingAdvance> {
    const [summary, rows] = await this.db.call<Row>('sp_advance_pending', [employeeId]);
    const s = firstRow<Omit<PendingAdvance, 'advances'>>(summary)!;
    return { ...s, advances: mapRows(rows) };
  }
}
