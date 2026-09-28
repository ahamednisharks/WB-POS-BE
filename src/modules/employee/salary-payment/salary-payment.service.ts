import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../../../config/configuration';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { decrypt, maskTail } from '../../../common/utils/crypto.util';
import { MarkPaidDto, SalaryCalculateQueryDto, SalaryPaymentListQueryDto, SalaryPaymentSaveDto } from './dto/salary-payment.dto';
import { SalaryCalculation, SalaryPayment, SalaryPaymentRepository, SalarySlipData } from './salary-payment.repository';

@Injectable()
export class SalaryPaymentService {
  private readonly key: string;

  constructor(
    private readonly repo: SalaryPaymentRepository,
    config: ConfigService<AppConfig, true>,
  ) {
    this.key = config.get('aesKey', { infer: true });
  }

  async list(q: SalaryPaymentListQueryDto): Promise<ApiResult<SalaryPayment[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total, { totals: r.totals });
  }

  get(id: number): Promise<SalaryPayment> {
    return this.repo.get(id);
  }

  calculate(q: SalaryCalculateQueryDto): Promise<SalaryCalculation> {
    return this.repo.calculate(q);
  }

  async save(id: number, dto: SalaryPaymentSaveDto, userId: number): Promise<ApiResult<SalaryPayment>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async markPaid(id: number, dto: MarkPaidDto, userId: number): Promise<ApiResult<SalaryPayment>> {
    const res = await this.repo.markPaid(id, dto, userId);
    return ok(await this.repo.get(id), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  /** Slip shows only the last 4 digits of the bank account. */
  async slip(id: number): Promise<SalarySlipData> {
    const data = await this.repo.slip(id);
    if (data.payment) {
      const { bankAccountEnc, ...payment } = data.payment;
      let bank = '';
      if (typeof bankAccountEnc === 'string' && bankAccountEnc) {
        try {
          bank = decrypt(bankAccountEnc, this.key);
        } catch {
          bank = '';
        }
      }
      data.payment = { ...payment, bankAccount: maskTail(bank) };
    }
    return data;
  }
}
