import { Body, Controller, Get, Param, ParseIntPipe, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult } from '../../../common/utils/api-result';
import { DayClose, DayClosePreview } from './day-close.repository';
import { DayCloseService } from './day-close.service';
import { DayCloseListQueryDto, DayClosePreviewQueryDto, DayCloseSaveDto } from './dto/day-close.dto';

@ApiTags('Transactions - Day close')
@Controller('day-close')
export class DayCloseController {
  constructor(private readonly service: DayCloseService) {}

  @Get('preview')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Opening suggestion, cash sales, refunds, cash outs, expected cash (sp_day_close_preview)' })
  preview(@Query() q: DayClosePreviewQueryDto, @CurrentUser() user: AuthUser): Promise<DayClosePreview> {
    return this.service.preview(q.date, user);
  }

  @Post()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({
    summary: 'Close the day (sp_day_close_save)',
    description: 'Cash figures are recomputed server-side. Remarks required when counted cash differs. One close per user per day; ADMIN may re-close.',
  })
  save(@Body() dto: DayCloseSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<DayClose>> {
    return this.service.save(dto, user);
  }

  @Get()
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Day close history (sp_day_close_list)' })
  list(@Query() q: DayCloseListQueryDto): Promise<ApiResult<DayClose[]>> {
    return this.service.list(q);
  }

  @Get(':id')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'One day close, for the slip (sp_day_close_get)' })
  get(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<DayClose> {
    return this.service.get(id, user);
  }
}
