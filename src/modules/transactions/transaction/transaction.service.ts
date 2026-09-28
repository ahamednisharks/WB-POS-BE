import { Injectable, StreamableFile } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, paged } from '../../../common/utils/api-result';
import { SettingsService } from '../../settings/settings.service';
import { TransactionExportQueryDto, TransactionListQueryDto } from './dto/transaction.dto';
import { TransactionExportService } from './transaction-export.service';
import { Transaction, TransactionRepository } from './transaction.repository';

@Injectable()
export class TransactionService {
  constructor(
    private readonly repo: TransactionRepository,
    private readonly exporter: TransactionExportService,
    private readonly settings: SettingsService,
  ) {}

  async list(q: TransactionListQueryDto, user: AuthUser): Promise<ApiResult<Transaction[]>> {
    const r = await this.repo.list(q, user);
    return paged(r.data, r.total, { summary: r.summary });
  }

  async export(q: TransactionExportQueryDto, user: AuthUser): Promise<StreamableFile> {
    const { rows, summary } = await this.repo.export(q, user);
    const shop = await this.settings.get();
    const meta = { shopName: shop?.shopName ?? 'WB Bakery', from: q.from ?? null, to: q.to ?? null };
    const stamp = `${q.from ?? 'all'}_${q.to ?? 'all'}`;

    if (q.format === 'pdf') {
      const pdf = await this.exporter.toPdf(rows, summary, meta);
      return new StreamableFile(pdf, { type: 'application/pdf', disposition: `attachment; filename="transactions_${stamp}.pdf"` });
    }
    const xlsx = await this.exporter.toExcel(rows, summary, meta);
    return new StreamableFile(xlsx, {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      disposition: `attachment; filename="transactions_${stamp}.xlsx"`,
    });
  }
}
