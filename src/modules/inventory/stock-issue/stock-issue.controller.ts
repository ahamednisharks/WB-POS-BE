import { Body, Controller, Get, HttpCode, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult } from '../../../common/utils/api-result';
import { StockIssueCancelDto, StockIssueListQueryDto, StockIssueSaveDto } from './dto/stock-issue.dto';
import { StockIssue, StockIssueService } from './stock-issue.service';

@ApiTags('Inventory - Stock issues')
@Controller('stock-issues')
@Roles('ADMIN', 'CASHIER')
export class StockIssueController {
  constructor(private readonly service: StockIssueService) {}

  @Get()
  @ApiOperation({ summary: 'List stock issues + footer totals (sp_stock_issue_list). Filters: from, to, reason, status' })
  list(@Query() q: StockIssueListQueryDto, @CurrentUser() user: AuthUser): Promise<ApiResult<StockIssue[]>> {
    return this.service.list(q, user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Stock issue with its lines (sp_stock_issue_get)' })
  get(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<StockIssue> {
    return this.service.get(id, user);
  }

  @Post()
  @ApiOperation({ summary: 'Record raw material sent to production / wasted: stock OUT per line (sp_stock_issue_save)' })
  create(@Body() dto: StockIssueSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<StockIssue>> {
    return this.service.save(0, dto, user);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Edit a stock issue on the day it was created, by its creator or an admin (sp_stock_issue_save)' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: StockIssueSaveDto,
    @CurrentUser() user: AuthUser,
  ): Promise<ApiResult<StockIssue>> {
    return this.service.save(id, dto, user);
  }

  @Post(':id/cancel')
  @HttpCode(200)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Cancel a stock issue and put every line back into stock (sp_stock_issue_cancel)' })
  cancel(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: StockIssueCancelDto,
    @CurrentUser() user: AuthUser,
  ): Promise<ApiResult<StockIssue>> {
    return this.service.cancel(id, dto, user);
  }
}
