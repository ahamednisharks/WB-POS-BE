import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { IssueReason, IssueStatus, StockIssueListQueryDto, StockIssueSaveDto } from './dto/stock-issue.dto';

export interface StockIssueItemRow {
  itemId: string;
  itemCode: string;
  itemName: string;
  unitCode: string;
  allowDecimal: boolean;
  qty: number;
  reason: IssueReason;
  /** items.purchase_price when the issue was posted. */
  rate: number;
  amount: number;
  remarks: string | null;
  /** The item's stock right now (so an edit form can show what is available). */
  currentStock: number;
}

/** Header as the SPs return it. */
export interface StockIssueRow {
  id: string;
  issueNo: string;
  issueDate: string;
  remarks: string | null;
  itemCount: number;
  totalValue: number;
  status: IssueStatus;
  /** users.id of the creator (plain number: toCamel only stringifies `id` / `*Id` keys). */
  issuedBy: number;
  issuedByName: string;
  /** List rows only: "Maavu x 2, Sugar x 1". */
  itemsSummary?: string | null;
  /** List rows only: distinct line reasons, comma separated. */
  reasons?: string | null;
  cancelReason: string | null;
  cancelledAt: string | null;
  cancelledByName: string | null;
  /** 1 = posted and created today; the service adds the creator / admin rule. */
  isEditable: number;
  createdAt: string;
  updatedAt: string;
}

export interface StockIssueTotals {
  postedCount: number;
  cancelledCount: number;
  totalValue: number;
}

@Injectable()
export class StockIssueRepository {
  constructor(private readonly db: DbService) {}

  async list(q: StockIssueListQueryDto): Promise<PagedData<StockIssueRow> & { totals: StockIssueTotals }> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count, totals] = await this.db.call<Row>('sp_stock_issue_list', [
      q.from ?? null,
      q.to ?? null,
      filterValue(q.reason),
      filterValue(q.status),
      searchOf(q),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<StockIssueRow>(rows), total: totalOf(count), totals: firstRow<StockIssueTotals>(totals)! };
  }

  async get(id: number): Promise<{ header: StockIssueRow; items: StockIssueItemRow[] }> {
    const [header, items] = await this.db.call<Row>('sp_stock_issue_get', [id]);
    return { header: firstRow<StockIssueRow>(header)!, items: mapRows<StockIssueItemRow>(items) };
  }

  async save(id: number, dto: StockIssueSaveDto, user: AuthUser): Promise<WriteResult> {
    const items = dto.items.map((i) => ({ itemId: i.itemId, qty: i.qty, reason: i.reason, remarks: i.remarks ?? null }));
    const [rows] = await this.db.call<Row>('sp_stock_issue_save', [
      id,
      dto.issueDate,
      dto.remarks ?? null,
      JSON.stringify(items),
      user.id,
      user.role,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async cancel(id: number, reason: string, user: AuthUser): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_stock_issue_cancel', [id, reason.trim(), user.id, user.role]);
    return firstRow<WriteResult>(rows)!;
  }
}
