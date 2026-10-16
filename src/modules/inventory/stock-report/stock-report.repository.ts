import { Injectable } from '@nestjs/common';
import { PagedData } from '../../../common/utils/api-result';
import { boolFlag, filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { StockSummaryQueryDto } from './dto/stock-report.dto';

/** One register row: opening + purchased + adjusted - used - wastage - sold = closing. */
export interface StockSummaryRow {
  id: string;
  code: string;
  name: string;
  type: 'RAW' | 'BOTH';
  categoryId: string;
  categoryName: string;
  unitCode: string;
  allowDecimal: boolean;
  opening: number;
  purchased: number;
  /** Issued with reason PRODUCTION (sent to the production unit). */
  used: number;
  /** Issued with any other reason. */
  wastage: number;
  /** BOTH items only: sold on bills (net of cancellations). */
  sold: number;
  /** Opening stock entries and manual adjustments (net). */
  adjusted: number;
  closing: number;
  currentStock: number;
  minStock: number;
  purchasePrice: number;
  stockValue: number;
  isLow: boolean;
}

export interface StockSummaryTotals {
  itemCount: number;
  lowCount: number;
  purchased: number;
  used: number;
  wastage: number;
  stockValue: number;
}

@Injectable()
export class StockReportRepository {
  constructor(private readonly db: DbService) {}

  async summary(q: StockSummaryQueryDto): Promise<PagedData<StockSummaryRow> & { totals: StockSummaryTotals }> {
    const { sortBy, sortDir } = sortOf(q, 'asc');
    const [rows, count, totals] = await this.db.call<Row>('sp_stock_summary', [
      q.from ?? null,
      q.to ?? null,
      q.categoryId ?? null,
      filterValue(q.type),
      boolFlag(q.lowOnly),
      searchOf(q),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<StockSummaryRow>(rows), total: totalOf(count), totals: firstRow<StockSummaryTotals>(totals)! };
  }
}
