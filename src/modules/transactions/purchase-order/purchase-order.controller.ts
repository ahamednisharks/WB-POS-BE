import { Body, Controller, Delete, Get, HttpCode, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { PoCancelDto, PoListQueryDto, PoOpenQueryDto, PoSaveDto } from './dto/purchase-order.dto';
import { OpenPo, PendingPoItem, PurchaseOrder } from './purchase-order.repository';
import { PurchaseOrderService } from './purchase-order.service';

@ApiTags('Transactions - Purchase orders')
@Controller('purchase-orders')
@Roles('ADMIN')
export class PurchaseOrderController {
  constructor(private readonly service: PurchaseOrderService) {}

  @Get()
  @ApiOperation({ summary: 'List POs with items (sp_po_list). Filters: supplierId, status (OPEN = SENT+PARTIAL), from, to' })
  list(@Query() q: PoListQueryDto): Promise<ApiResult<PurchaseOrder[]>> {
    return this.service.list(q);
  }

  @Get('open')
  @ApiOperation({ summary: 'SENT / PARTIAL orders of a supplier (sp_po_open_by_supplier)' })
  open(@Query() q: PoOpenQueryDto): Promise<OpenPo[]> {
    return this.service.openBySupplier(q.supplierId);
  }

  @Get(':id/pending-items')
  @ApiOperation({ summary: 'Lines still to be received, for Convert to PE (sp_po_pending_items)' })
  pendingItems(@Param('id', ParseIntPipe) id: number): Promise<PendingPoItem[]> {
    return this.service.pendingItems(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'PO with items and pending qty (sp_po_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<PurchaseOrder> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create PO as DRAFT or SENT (sp_po_save)' })
  create(@Body() dto: PoSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PurchaseOrder>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Edit a DRAFT PO (sp_po_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: PoSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PurchaseOrder>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a DRAFT PO (sp_po_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }

  @Post(':id/cancel')
  @HttpCode(200)
  @ApiOperation({ summary: 'Cancel a DRAFT or SENT PO (sp_po_cancel)' })
  cancel(@Param('id', ParseIntPipe) id: number, @Body() dto: PoCancelDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PurchaseOrder>> {
    return this.service.cancel(id, dto.reason, user.id);
  }
}
