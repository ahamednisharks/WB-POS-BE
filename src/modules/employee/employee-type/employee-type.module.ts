import { Module } from '@nestjs/common';
import { EmployeeTypeController } from './employee-type.controller';
import { EmployeeTypeRepository } from './employee-type.repository';
import { EmployeeTypeService } from './employee-type.service';

@Module({
  controllers: [EmployeeTypeController],
  providers: [EmployeeTypeRepository, EmployeeTypeService],
})
export class EmployeeTypeModule {}
