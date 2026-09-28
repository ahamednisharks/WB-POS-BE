import { Injectable } from '@nestjs/common';
import { Customer, CustomerRepository } from './customer.repository';

@Injectable()
export class CustomerService {
  constructor(private readonly repo: CustomerRepository) {}

  getByMobile(mobile: string): Promise<Customer> {
    return this.repo.getByMobile(mobile);
  }
}
