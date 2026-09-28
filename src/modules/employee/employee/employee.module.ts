import { Module } from '@nestjs/common';
import { EmployeeController } from './employee.controller';
import { EmployeeRepository } from './employee.repository';
import { EmployeeService } from './employee.service';

@Module({
  controllers: [EmployeeController],
  providers: [EmployeeRepository, EmployeeService],
})
export class EmployeeCoreModule {}
