import { Body, Controller, Get, HttpCode, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult } from '../../../common/utils/api-result';
import { PreOrderCancelDto, PreOrderDeliverDto, PreOrderListQueryDto, PreOrderPaymentsDto, PreOrderSaveDto } from './dto/pre-order.dto';
import { PreOrderService } from './pre-order.service';
import { PreOrder, PreOrderListRow, PreOrderNextNo } from './pre-order.types';

@ApiTags('Billing - Pre-orders')
@Controller('pre-orders')
@Roles('ADMIN', 'CASHIER')
export class PreOrderController {
  constructor(private readonly service: PreOrderService) {}

  @Get()
  @ApiOperation({ summary: 'List pre-orders by delivery date (sp_preorder_list). status: BOOKED | READY | DELIVERED | CANCELLED | OPEN' })
  list(@Query() q: PreOrderListQueryDto): Promise<ApiResult<PreOrderListRow[]>> {
    return this.service.list(q);
  }

  @Get('next-no')
  @ApiOperation({ summary: 'Number and date for the New Pre-Order screen; the number is only taken on save (sp_preorder_next_no)' })
  nextNo(): Promise<PreOrderNextNo> {
    return this.service.nextNo();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Pre-order with lines and payments (sp_preorder_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<PreOrder> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Book a pre-order, optionally with an advance (sp_preorder_save)' })
  create(@Body() dto: PreOrderSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PreOrder>> {
    return this.service.save(0, dto, user);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Edit a BOOKED / READY pre-order (sp_preorder_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: PreOrderSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PreOrder>> {
    return this.service.save(id, dto, user);
  }

  @Post(':id/payments')
  @HttpCode(200)
  @ApiOperation({ summary: 'Take another payment before delivery (sp_preorder_add_payment)' })
  addPayments(@Param('id', ParseIntPipe) id: number, @Body() dto: PreOrderPaymentsDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PreOrder>> {
    return this.service.addPayments(id, dto.payments, user);
  }

  @Post(':id/ready')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark a BOOKED pre-order ready (sp_preorder_mark_ready)' })
  markReady(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<PreOrder>> {
    return this.service.markReady(id, user);
  }

  @Post(':id/deliver')
  @HttpCode(200)
  @ApiOperation({ summary: 'Collect the balance and generate the bill (sp_preorder_deliver)' })
  deliver(@Param('id', ParseIntPipe) id: number, @Body() dto: PreOrderDeliverDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PreOrder>> {
    return this.service.deliver(id, dto.payments, user);
  }

  @Post(':id/cancel')
  @HttpCode(200)
  @Roles('ADMIN')
  @ApiOperation({ summary: 'ADMIN: cancel and refund all, part or none of the amount paid (sp_preorder_cancel)' })
  cancel(@Param('id', ParseIntPipe) id: number, @Body() dto: PreOrderCancelDto, @CurrentUser() user: AuthUser): Promise<ApiResult<PreOrder>> {
    return this.service.cancel(id, dto, user);
  }
}
