import { Module } from '@nestjs/common';
import { SalarySetupController } from './salary-setup.controller';
import { SalarySetupRepository } from './salary-setup.repository';
import { SalarySetupService } from './salary-setup.service';

@Module({
  controllers: [SalarySetupController],
  providers: [SalarySetupRepository, SalarySetupService],
})
export class SalarySetupModule {}
