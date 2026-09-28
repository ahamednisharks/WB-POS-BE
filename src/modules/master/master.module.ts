import { Module } from '@nestjs/common';
import { CategoryModule } from './category/category.module';
import { ComboModule } from './combo/combo.module';
import { ItemModule } from './item/item.module';
import { SupplierModule } from './supplier/supplier.module';
import { UnitModule } from './unit/unit.module';

@Module({
  imports: [UnitModule, CategoryModule, ItemModule, ComboModule, SupplierModule],
})
export class MasterModule {}
