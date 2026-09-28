import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { PagedData, WriteResult } from '../../../common/utils/api-result';
import { pageArgs } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { DayCloseListQueryDto, DayCloseSaveDto } from './dto/day-close.dto';

export interface DayClose {
  id: string;
  date: string;
  openingCash: number;
  cashSales: number;
  cashRefunds: number;
  cashOuts: number;
  expectedCash: number;
  countedCash: number;
  difference: number;
  remarks: string;
  closedById: string;
  closedByName: string;
  createdAt: string;
  updatedAt: string;
}

export interface DayClosePreview {
  date: string;
  openingCash: number;
  cashSales: number;
  cashRefunds: number;
  cashOuts: number;
  expectedCash: number;
  existingId: string | null;
  alreadyClosed: number;
}

@Injectable()
export class DayCloseRepository {
  constructor(private readonly db: DbService) {}

  async preview(date: string | null, user: AuthUser): Promise<DayClosePreview> {
    const [rows] = await this.db.call<Row>('sp_day_close_preview', [date, user.id, user.role]);
    return firstRow<DayClosePreview>(rows)!;
  }

  async save(dto: DayCloseSaveDto, user: AuthUser): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_day_close_save', [
      dto.date ?? null,
      dto.openingCash,
      dto.countedCash,
      dto.remarks ?? null,
      user.id,
      user.role,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async get(id: number, user: AuthUser): Promise<DayClose> {
    const [rows] = await this.db.call<Row>('sp_day_close_get', [id, user.id, user.role]);
    return firstRow<DayClose>(rows)!;
  }

  async list(q: DayCloseListQueryDto): Promise<PagedData<DayClose>> {
    const [rows, count] = await this.db.call<Row>('sp_day_close_list', [q.from ?? null, q.to ?? null, q.cashierId ?? null, ...pageArgs(q)]);
    return { data: mapRows<DayClose>(rows), total: totalOf(count) };
  }
}
