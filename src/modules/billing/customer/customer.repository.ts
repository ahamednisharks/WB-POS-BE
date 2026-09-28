import { Injectable } from '@nestjs/common';
import { firstRow, Row } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';

export interface Customer {
  id: string;
  mobile: string;
  name: string;
  totalSpent: number;
  visitCount: number;
  lastVisitAt: string | null;
}

@Injectable()
export class CustomerRepository {
  constructor(private readonly db: DbService) {}

  async getByMobile(mobile: string): Promise<Customer> {
    const [rows] = await this.db.call<Row>('sp_customer_get_by_mobile', [mobile]);
    return firstRow<Customer>(rows)!;
  }
}
