import { Module } from '@nestjs/common';
import { AdvanceModule } from './advance/advance.module';
import { EmployeeCoreModule } from './employee/employee.module';
import { EmployeeTypeModule } from './employee-type/employee-type.module';
import { LoginAccountModule } from './login/login-account.module';
import { SalaryPaymentModule } from './salary-payment/salary-payment.module';
import { SalarySetupModule } from './salary-setup/salary-setup.module';

@Module({
  imports: [EmployeeTypeModule, EmployeeCoreModule, AdvanceModule, SalarySetupModule, SalaryPaymentModule, LoginAccountModule],
})
export class EmployeeModule {}
