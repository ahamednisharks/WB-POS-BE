import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { PeListQueryDto, PePaymentDto, PeSaveDto } from './dto/purchase-entry.dto';
import { PurchaseEntry, PurchaseEntryService } from './purchase-entry.service';

@ApiTags('Transactions - Purchase entries')
@Controller('purchase-entries')
@Roles('ADMIN')
export class PurchaseEntryController {
  constructor(private readonly service: PurchaseEntryService) {}

  @Get()
  @ApiOperation({ summary: 'List purchase entries + footer totals (sp_pe_list). Filters: supplierId, paymentStatus, from, to' })
  list(@Query() q: PeListQueryDto): Promise<ApiResult<PurchaseEntry[]>> {
    return this.service.list(q);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Purchase entry with items and payments (sp_pe_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<PurchaseEntry> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Record goods received: stock, PO progress, supplier balance, payment (sp_pe_save)' })
  create(@Body() dto: PeSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PurchaseEntry>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Edit a purchase entry on the day it was created (sp_pe_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: PeSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PurchaseEntry>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a purchase entry on the day it was created (sp_pe_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }

  @Post(':id/payments')
  @ApiOperation({ summary: 'Pay against the balance (sp_pe_add_payment)' })
  addPayment(@Param('id', ParseIntPipe) id: number, @Body() dto: PePaymentDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PurchaseEntry>> {
    return this.service.addPayment(id, dto, user.id);
  }
}
