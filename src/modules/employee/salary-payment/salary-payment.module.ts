import { Module } from '@nestjs/common';
import { SalaryPaymentController } from './salary-payment.controller';
import { SalaryPaymentRepository } from './salary-payment.repository';
import { SalaryPaymentService } from './salary-payment.service';

@Module({
  controllers: [SalaryPaymentController],
  providers: [SalaryPaymentRepository, SalaryPaymentService],
})
export class SalaryPaymentModule {}
