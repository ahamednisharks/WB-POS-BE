import { Injectable } from '@nestjs/common';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { MarkPaidDto, SalaryCalculateQueryDto, SalaryPaymentListQueryDto, SalaryPaymentSaveDto } from './dto/salary-payment.dto';

export interface SalaryPayment {
  id: string;
  month: string;
  employeeId: string;
  empCode: string;
  employeeName: string;
  workingDays: number;
  daysPresent: number;
  gross: number;
  bonus: number;
  advanceDeduction: number;
  otherDeductions: number;
  deductionReason: string;
  net: number;
  paymentDate: string | null;
  paymentMode: 'CASH' | 'BANK' | 'UPI' | null;
  status: 'PENDING' | 'PAID';
  createdAt: string;
  updatedAt: string;
}

export interface SalaryTotals {
  records: number;
  gross: number;
  bonus: number;
  advanceDeduction: number;
  otherDeductions: number;
  net: number;
  paid: number;
  pending: number;
}

export interface SalaryCalculation {
  employeeId: string;
  empCode: string;
  employeeName: string;
  month: string;
  salaryType: 'MONTHLY' | 'DAILY';
  basicSalary: number;
  allowances: number;
  effectiveFrom: string;
  workingDays: number;
  daysPresent: number;
  gross: number;
  pendingAdvance: number;
  existingId: string | null;
}

export interface SalarySlipData {
  shop: Row | null;
  payment: Row | null;
}

@Injectable()
export class SalaryPaymentRepository {
  constructor(private readonly db: DbService) {}

  async list(q: SalaryPaymentListQueryDto): Promise<PagedData<SalaryPayment> & { totals: SalaryTotals }> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count, totals] = await this.db.call<Row>('sp_salary_payment_list', [
      searchOf(q),
      q.month ?? null,
      q.employeeId ?? null,
      filterValue(q.payStatus ?? q.status),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<SalaryPayment>(rows), total: totalOf(count), totals: firstRow<SalaryTotals>(totals)! };
  }

  async get(id: number): Promise<SalaryPayment> {
    const [rows] = await this.db.call<Row>('sp_salary_payment_get', [id]);
    return firstRow<SalaryPayment>(rows)!;
  }

  async calculate(q: SalaryCalculateQueryDto): Promise<SalaryCalculation> {
    const [rows] = await this.db.call<Row>('sp_salary_payment_calculate', [q.employeeId, q.month, q.workingDays, q.daysPresent]);
    return firstRow<SalaryCalculation>(rows)!;
  }

  async save(id: number, dto: SalaryPaymentSaveDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_salary_payment_save', [
      id,
      dto.employeeId,
      dto.month,
      dto.workingDays,
      dto.daysPresent,
      dto.bonus ?? 0,
      dto.advanceDeduction ?? 0,
      dto.otherDeductions ?? 0,
      dto.deductionReason ?? null,
      dto.status ?? 'PENDING',
      dto.paymentDate ?? null,
      dto.paymentMode ?? null,
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async markPaid(id: number, dto: MarkPaidDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_salary_payment_mark_paid', [id, dto.paymentDate, dto.paymentMode, userId]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_salary_payment_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async slip(id: number): Promise<SalarySlipData> {
    const [shop, payment] = await this.db.call<Row>('sp_salary_payment_slip', [id]);
    return { shop: firstRow(shop), payment: firstRow(payment) };
  }
}
