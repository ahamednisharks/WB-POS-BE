import { Injectable } from '@nestjs/common';
import { ApiResult, paged } from '../../../common/utils/api-result';
import { StockSummaryQueryDto } from './dto/stock-report.dto';
import { StockReportRepository, StockSummaryRow } from './stock-report.repository';

@Injectable()
export class StockReportService {
  constructor(private readonly repo: StockReportRepository) {}

  async summary(q: StockSummaryQueryDto): Promise<ApiResult<StockSummaryRow[]>> {
    const r = await this.repo.summary(q);
    const totals = {
      itemCount: Number(r.totals.itemCount),
      lowCount: Number(r.totals.lowCount),
      purchased: Number(r.totals.purchased),
      used: Number(r.totals.used),
      wastage: Number(r.totals.wastage),
      stockValue: Number(r.totals.stockValue),
    };
    return paged(r.data, r.total, { totals });
  }
}
