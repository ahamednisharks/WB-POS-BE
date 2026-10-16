import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, ok, paged } from '../../../common/utils/api-result';
import { StockIssueCancelDto, StockIssueListQueryDto, StockIssueSaveDto } from './dto/stock-issue.dto';
import { StockIssueItemRow, StockIssueRepository, StockIssueRow } from './stock-issue.repository';

/** Stock issue as the API exposes it (frontend `StockIssue` model). */
export type StockIssue = Omit<StockIssueRow, 'isEditable'> & {
  /** Posted, created today, and the caller is the creator or an ADMIN. */
  isEditable: boolean;
  items: StockIssueItemRow[];
};

@Injectable()
export class StockIssueService {
  constructor(private readonly repo: StockIssueRepository) {}

  private view(row: StockIssueRow, user: AuthUser, items: StockIssueItemRow[] = []): StockIssue {
    const { isEditable, ...rest } = row;
    const mine = user.role === 'ADMIN' || Number(row.issuedBy) === user.id;
    return { ...rest, issuedBy: Number(row.issuedBy), isEditable: isEditable === 1 && mine, items };
  }

  async list(q: StockIssueListQueryDto, user: AuthUser): Promise<ApiResult<StockIssue[]>> {
    const r = await this.repo.list(q);
    const totals = {
      postedCount: Number(r.totals.postedCount),
      cancelledCount: Number(r.totals.cancelledCount),
      totalValue: Number(r.totals.totalValue),
    };
    return paged(r.data.map((row) => this.view(row, user)), r.total, { totals });
  }

  async get(id: number, user: AuthUser): Promise<StockIssue> {
    const r = await this.repo.get(id);
    return this.view(r.header, user, r.items);
  }

  async save(id: number, dto: StockIssueSaveDto, user: AuthUser): Promise<ApiResult<StockIssue>> {
    const res = await this.repo.save(id, dto, user);
    return ok(await this.get(Number(res.id), user), res.message);
  }

  async cancel(id: number, dto: StockIssueCancelDto, user: AuthUser): Promise<ApiResult<StockIssue>> {
    const res = await this.repo.cancel(id, dto.reason, user);
    return ok(await this.get(id, user), res.message);
  }
}
