import { Module } from '@nestjs/common';
import { StockIssueController } from './stock-issue/stock-issue.controller';
import { StockIssueRepository } from './stock-issue/stock-issue.repository';
import { StockIssueService } from './stock-issue/stock-issue.service';
import { StockReportController } from './stock-report/stock-report.controller';
import { StockReportRepository } from './stock-report/stock-report.repository';
import { StockReportService } from './stock-report/stock-report.service';

/**
 * Raw material stock maintenance: Stock Issue documents (warehouse -> production unit / wastage) and the
 * stock register report. Purchases (stock in) live in TransactionsModule; opening stock / adjustments and
 * the per-item ledger stay on the item endpoints in MasterModule.
 */
@Module({
  controllers: [StockIssueController, StockReportController],
  providers: [StockIssueRepository, StockIssueService, StockReportRepository, StockReportService],
})
export class InventoryModule {}
