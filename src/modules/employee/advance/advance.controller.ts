import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { Advance, PendingAdvance } from './advance.repository';
import { AdvanceService } from './advance.service';
import { AdvanceListQueryDto, AdvanceSaveDto } from './dto/advance.dto';

@ApiTags('Employee - Advances')
@Controller('employee-advances')
@Roles('ADMIN')
export class AdvanceController {
  constructor(private readonly service: AdvanceService) {}

  @Get()
  @ApiOperation({ summary: 'List salary advances (sp_advance_list). Filters: employeeId, from, to, pendingOnly' })
  list(@Query() q: AdvanceListQueryDto): Promise<ApiResult<Advance[]>> {
    return this.service.list(q);
  }

  @Get('pending/:employeeId')
  @ApiOperation({ summary: 'Outstanding advance of an employee (sp_advance_pending)' })
  pending(@Param('employeeId', ParseIntPipe) employeeId: number): Promise<PendingAdvance> {
    return this.service.pending(employeeId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get advance (sp_advance_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Advance> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Record an advance (sp_advance_save)' })
  create(@Body() dto: AdvanceSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Advance>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update an advance (sp_advance_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: AdvanceSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Advance>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete an advance that has not been recovered (sp_advance_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
