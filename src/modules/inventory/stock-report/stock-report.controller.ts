import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../../common/decorators/roles.decorator';
import { ApiResult } from '../../../common/utils/api-result';
import { StockSummaryQueryDto } from './dto/stock-report.dto';
import { StockSummaryRow } from './stock-report.repository';
import { StockReportService } from './stock-report.service';

@ApiTags('Inventory - Stock report')
@Controller('stock')
@Roles('ADMIN')
export class StockReportController {
  constructor(private readonly service: StockReportService) {}

  @Get('summary')
  @ApiOperation({
    summary:
      'Stock register per raw material: opening, purchased, used, wastage, sold, adjusted, closing + totals (sp_stock_summary). ' +
      'Filters: from, to (empty = all time), categoryId, type, lowOnly, search',
  })
  summary(@Query() q: StockSummaryQueryDto): Promise<ApiResult<StockSummaryRow[]>> {
    return this.service.summary(q);
  }
}
