import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { Combo, ComboOption } from './combo.repository';
import { ComboService } from './combo.service';
import { ComboListQueryDto, ComboSaveDto } from './dto/combo.dto';

@ApiTags('Master - Combos')
@Controller('combos')
@Roles('ADMIN')
export class ComboController {
  constructor(private readonly service: ComboService) {}

  @Get()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'List combos with their items (sp_combo_list). Filter activeOn=YYYY-MM-DD' })
  list(@Query() q: ComboListQueryDto): Promise<ApiResult<Combo[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Combos active and valid today (sp_combo_dropdown)' })
  dropdown(): Promise<ComboOption[]> {
    return this.service.dropdown();
  }

  @Get(':id')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Get combo with items (sp_combo_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Combo> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create combo (sp_combo_save). Needs >= 2 items and price below actual price' })
  create(@Body() dto: ComboSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Combo>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update combo (sp_combo_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: ComboSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Combo>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete combo, or mark inactive when billed (sp_combo_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
