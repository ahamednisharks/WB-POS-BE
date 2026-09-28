import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../../common/decorators/roles.decorator';
import { Catalog } from './catalog.repository';
import { CatalogService } from './catalog.service';

@ApiTags('Billing - Catalog')
@Controller('billing')
@Roles('ADMIN', 'CASHIER')
export class CatalogController {
  constructor(private readonly service: CatalogService) {}

  @Get('catalog')
  @ApiOperation({ summary: 'Categories, sale items and today\'s combos in one call (sp_billing_catalog)' })
  catalog(): Promise<Catalog> {
    return this.service.catalog();
  }
}
