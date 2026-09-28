import { Module } from '@nestjs/common';
import { AdvanceController } from './advance.controller';
import { AdvanceRepository } from './advance.repository';
import { AdvanceService } from './advance.service';

@Module({
  controllers: [AdvanceController],
  providers: [AdvanceRepository, AdvanceService],
})
export class AdvanceModule {}
