import { BadRequestException, Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../../common/decorators/roles.decorator';
import { PATTERNS } from '../../../common/dto/validators';
import { Customer } from './customer.repository';
import { CustomerService } from './customer.service';

@ApiTags('Billing - Customers')
@Controller('customers')
@Roles('ADMIN', 'CASHIER')
export class CustomerController {
  constructor(private readonly service: CustomerService) {}

  @Get('by-mobile/:mobile')
  @ApiOperation({ summary: 'Returning customer lookup (sp_customer_get_by_mobile)' })
  byMobile(@Param('mobile') mobile: string): Promise<Customer> {
    if (!PATTERNS.mobile.test(mobile)) throw new BadRequestException({ message: 'Enter a valid 10-digit mobile number', field: 'mobile' });
    return this.service.getByMobile(mobile);
  }
}
