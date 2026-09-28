import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { ListQueryDto } from '../../../common/dto/list-query.dto';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { UnitSaveDto } from './dto/unit.dto';
import { Unit, UnitOption } from './unit.repository';
import { UnitService } from './unit.service';

@ApiTags('Master - Units')
@Controller('units')
@Roles('ADMIN')
export class UnitController {
  constructor(private readonly service: UnitService) {}

  @Get()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'List units (sp_unit_list)' })
  list(@Query() q: ListQueryDto): Promise<ApiResult<Unit[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Active units (sp_unit_dropdown)' })
  dropdown(): Promise<UnitOption[]> {
    return this.service.dropdown();
  }

  @Get(':id')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Get unit (sp_unit_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Unit> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create unit (sp_unit_save, id = 0)' })
  create(@Body() dto: UnitSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Unit>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update unit (sp_unit_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UnitSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Unit>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete unit, or mark inactive when in use (sp_unit_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
