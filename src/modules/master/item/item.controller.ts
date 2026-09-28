import { Body, Controller, Delete, Get, HttpCode, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { ItemDropdownQueryDto, ItemListQueryDto, ItemSaveDto, StockAdjustDto, StockLedgerQueryDto } from './dto/item.dto';
import { Item, ItemOption, StockLedgerRow } from './item.repository';
import { ItemService } from './item.service';

@ApiTags('Master - Items')
@Controller('items')
@Roles('ADMIN')
export class ItemController {
  constructor(private readonly service: ItemService) {}

  @Get()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'List items (sp_item_list). Filters: categoryId, type, barcode, saleable, purchasable, lowStock' })
  list(@Query() q: ItemListQueryDto): Promise<ApiResult<Item[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Active items; type=SALE -> SALE+BOTH, type=RAW -> RAW+BOTH (sp_item_dropdown)' })
  dropdown(@Query() q: ItemDropdownQueryDto): Promise<ItemOption[]> {
    return this.service.dropdown(q.type);
  }

  @Get('by-barcode/:code')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Scanner lookup (sp_item_get_by_barcode)' })
  byBarcode(@Param('code') code: string): Promise<Item> {
    return this.service.getByBarcode(code);
  }

  @Get(':id/stock-ledger')
  @ApiOperation({ summary: 'Stock movements of an item (sp_item_stock_ledger)' })
  stockLedger(@Param('id', ParseIntPipe) id: number, @Query() q: StockLedgerQueryDto): Promise<ApiResult<StockLedgerRow[]>> {
    return this.service.stockLedger(id, q);
  }

  @Post(':id/stock-adjust')
  @HttpCode(200)
  @ApiOperation({ summary: 'Opening stock / production / wastage correction (sp_item_stock_adjust)' })
  stockAdjust(@Param('id', ParseIntPipe) id: number, @Body() dto: StockAdjustDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Item>> {
    return this.service.stockAdjust(id, dto, user.id);
  }

  @Get(':id')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Get item (sp_item_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Item> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create item (sp_item_save, id = 0)' })
  create(@Body() dto: ItemSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Item>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update item (sp_item_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: ItemSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Item>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete item, or mark inactive when in use (sp_item_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
