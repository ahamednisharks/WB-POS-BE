import { Body, Controller, Delete, Get, HttpCode, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { HeldBill } from './bill.repository';
import { BillService } from './bill.service';
import { Bill, BillHeader, BillPayment, BillSyncResult, Receipt } from './bill.types';
import { BillCancelDto, BillListQueryDto, BillSaveDto, BillSyncDto, ReceiptQueryDto } from './dto/bill.dto';

@ApiTags('Billing - Bills')
@Controller('bills')
@Roles('ADMIN', 'CASHIER')
export class BillController {
  constructor(private readonly service: BillService) {}

  @Post()
  @ApiOperation({
    summary: 'Save a bill as HELD or COMPLETED (sp_bill_save). Totals are recomputed server-side',
    description: 'Send heldBillId to update or complete a held bill. A repeated clientRef returns the original bill.',
  })
  @ApiCreatedResponse({
    schema: {
      example: {
        success: true,
        message: 'Bill B2627-000001 saved',
        data: { id: '1', billNo: 'B2627-000001', grandTotal: 1030, status: 'COMPLETED', lines: [], payments: [], history: [] },
      },
    },
  })
  save(@Body() dto: BillSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Bill>> {
    return this.service.save(dto, user);
  }

  @Post('sync')
  @HttpCode(200)
  @ApiOperation({ summary: 'Upload the offline queue; returns { clientRef, id, billNo, error? } per bill' })
  sync(@Body() dto: BillSyncDto, @CurrentUser() user: AuthUser): Promise<ApiResult<BillSyncResult[]>> {
    return this.service.sync(dto.bills, user);
  }

  @Get()
  @ApiOperation({ summary: 'List bills (sp_bill_list). Cashiers only see their own' })
  list(@Query() q: BillListQueryDto, @CurrentUser() user: AuthUser): Promise<ApiResult<(BillHeader & { payments: BillPayment[] })[]>> {
    return this.service.list(q, user);
  }

  @Get('held')
  @ApiOperation({ summary: 'Held bills (sp_bill_held_list)' })
  held(@CurrentUser() user: AuthUser): Promise<HeldBill[]> {
    return this.service.heldList(user);
  }

  @Get(':id/receipt')
  @ApiOperation({ summary: 'Receipt data; duplicate=true marks a reprint (sp_bill_receipt)' })
  receipt(@Param('id', ParseIntPipe) id: number, @Query() q: ReceiptQueryDto, @CurrentUser() user: AuthUser): Promise<Receipt> {
    return this.service.receipt(id, q.duplicate ?? false, user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Bill with lines, payments and history (sp_bill_get)' })
  get(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<Bill> {
    return this.service.get(id, user);
  }

  @Put(':id/complete')
  @ApiOperation({ summary: 'Complete a held bill (sp_bill_complete_held)' })
  complete(@Param('id', ParseIntPipe) id: number, @Body() dto: BillSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Bill>> {
    return this.service.completeHeld(id, dto, user);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Discard a held bill (sp_bill_delete_held)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.deleteHeld(id, user);
  }

  @Post(':id/cancel')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Cancel a bill (sp_bill_cancel)',
    description: 'Completed bills: ADMIN only - reverses stock and records refunds. Held bills: the owner or an admin.',
  })
  cancel(@Param('id', ParseIntPipe) id: number, @Body() dto: BillCancelDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Bill>> {
    return this.service.cancel(id, dto.reason, dto.remarks ?? null, user);
  }
}
