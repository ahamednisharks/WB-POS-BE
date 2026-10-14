import { Module } from '@nestjs/common';
import { BillController } from './bill/bill.controller';
import { BillRepository } from './bill/bill.repository';
import { BillService } from './bill/bill.service';
import { CatalogController } from './catalog/catalog.controller';
import { CatalogRepository } from './catalog/catalog.repository';
import { CatalogService } from './catalog/catalog.service';
import { CustomerController } from './customer/customer.controller';
import { CustomerRepository } from './customer/customer.repository';
import { CustomerService } from './customer/customer.service';
import { PreOrderController } from './pre-order/pre-order.controller';
import { PreOrderRepository } from './pre-order/pre-order.repository';
import { PreOrderService } from './pre-order/pre-order.service';

@Module({
  controllers: [CatalogController, CustomerController, BillController, PreOrderController],
  providers: [
    CatalogRepository,
    CatalogService,
    CustomerRepository,
    CustomerService,
    BillRepository,
    BillService,
    PreOrderRepository,
    PreOrderService,
  ],
})
export class BillingModule {}
