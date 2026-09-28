import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsOptional } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { IsDateOnly } from '../../common/dto/validators';
import { DashboardData, DashboardService } from './dashboard.service';

export class DashboardQueryDto {
  @ApiPropertyOptional({ example: '2026-09-20', description: 'Defaults to today' }) @IsOptional() @IsDateOnly() from?: string;
  @ApiPropertyOptional({ example: '2026-09-26', description: 'Defaults to from' }) @IsOptional() @IsDateOnly() to?: string;
}

@ApiTags('Dashboard')
@Controller('dashboard')
@Roles('ADMIN')
export class DashboardController {
  constructor(private readonly service: DashboardService) {}

  @Get()
  @ApiOperation({ summary: 'Sales cards, payment split, hourly sales, top items, recent bills, low stock (sp_dashboard_summary)' })
  summary(@Query() q: DashboardQueryDto): Promise<DashboardData> {
    return this.service.summary(q.from, q.to);
  }
}
