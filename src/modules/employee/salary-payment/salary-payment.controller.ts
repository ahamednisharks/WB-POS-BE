import { Body, Controller, Delete, Get, HttpCode, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { MarkPaidDto, SalaryCalculateQueryDto, SalaryPaymentListQueryDto, SalaryPaymentSaveDto } from './dto/salary-payment.dto';
import { SalaryCalculation, SalaryPayment, SalarySlipData } from './salary-payment.repository';
import { SalaryPaymentService } from './salary-payment.service';

@ApiTags('Employee - Salary payments')
@Controller('salary-payments')
@Roles('ADMIN')
export class SalaryPaymentController {
  constructor(private readonly service: SalaryPaymentService) {}

  @Get()
  @ApiOperation({ summary: 'List salary records + totals (sp_salary_payment_list). Filters: month, employeeId, status' })
  list(@Query() q: SalaryPaymentListQueryDto): Promise<ApiResult<SalaryPayment[]>> {
    return this.service.list(q);
  }

  @Get('calculate')
  @ApiOperation({ summary: 'Preview gross salary and pending advance (sp_salary_payment_calculate)' })
  calculate(@Query() q: SalaryCalculateQueryDto): Promise<SalaryCalculation> {
    return this.service.calculate(q);
  }

  @Get(':id/slip')
  @ApiOperation({ summary: 'Salary slip data (sp_salary_payment_slip)' })
  slip(@Param('id', ParseIntPipe) id: number): Promise<SalarySlipData> {
    return this.service.slip(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get salary record (sp_salary_payment_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<SalaryPayment> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create salary record; gross is computed server-side (sp_salary_payment_save)' })
  create(@Body() dto: SalaryPaymentSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<SalaryPayment>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a PENDING salary record; status PAID marks it paid (sp_salary_payment_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: SalaryPaymentSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<SalaryPayment>> {
    return this.service.save(id, dto, user.id);
  }

  @Post(':id/mark-paid')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark as paid: recovers advances, CASH_OUT when cash (sp_salary_payment_mark_paid)' })
  markPaid(@Param('id', ParseIntPipe) id: number, @Body() dto: MarkPaidDto, @CurrentUser() user: AuthUser): Promise<ApiResult<SalaryPayment>> {
    return this.service.markPaid(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a PENDING salary record (sp_salary_payment_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
