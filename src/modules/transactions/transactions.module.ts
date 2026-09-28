import { Module } from '@nestjs/common';
import { SettingsModule } from '../settings/settings.module';
import { DayCloseController } from './day-close/day-close.controller';
import { DayCloseRepository } from './day-close/day-close.repository';
import { DayCloseService } from './day-close/day-close.service';
import { PurchaseEntryController } from './purchase-entry/purchase-entry.controller';
import { PurchaseEntryRepository } from './purchase-entry/purchase-entry.repository';
import { PurchaseEntryService } from './purchase-entry/purchase-entry.service';
import { PurchaseOrderController } from './purchase-order/purchase-order.controller';
import { PurchaseOrderRepository } from './purchase-order/purchase-order.repository';
import { PurchaseOrderService } from './purchase-order/purchase-order.service';
import { TransactionExportService } from './transaction/transaction-export.service';
import { TransactionController } from './transaction/transaction.controller';
import { TransactionRepository } from './transaction/transaction.repository';
import { TransactionService } from './transaction/transaction.service';

@Module({
  imports: [SettingsModule],
  controllers: [TransactionController, DayCloseController, PurchaseOrderController, PurchaseEntryController],
  providers: [
    TransactionRepository,
    TransactionExportService,
    TransactionService,
    DayCloseRepository,
    DayCloseService,
    PurchaseOrderRepository,
    PurchaseOrderService,
    PurchaseEntryRepository,
    PurchaseEntryService,
  ],
})
export class TransactionsModule {}
