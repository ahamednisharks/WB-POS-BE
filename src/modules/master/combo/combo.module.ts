import { Module } from '@nestjs/common';
import { ComboController } from './combo.controller';
import { ComboRepository } from './combo.repository';
import { ComboService } from './combo.service';

@Module({
  controllers: [ComboController],
  providers: [ComboRepository, ComboService],
})
export class ComboModule {}
