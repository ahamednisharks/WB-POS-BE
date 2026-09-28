import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { SupplierLedgerQueryDto, SupplierListQueryDto, SupplierSaveDto } from './dto/supplier.dto';
import { Supplier, SupplierLedger, SupplierOption } from './supplier.repository';
import { SupplierService } from './supplier.service';

@ApiTags('Master - Suppliers')
@Controller('suppliers')
@Roles('ADMIN')
export class SupplierController {
  constructor(private readonly service: SupplierService) {}

  @Get()
  @ApiOperation({ summary: 'List suppliers (sp_supplier_list). Filter: state' })
  list(@Query() q: SupplierListQueryDto): Promise<ApiResult<Supplier[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @ApiOperation({ summary: 'Active suppliers (sp_supplier_dropdown)' })
  dropdown(): Promise<SupplierOption[]> {
    return this.service.dropdown();
  }

  @Get(':id/ledger')
  @ApiOperation({ summary: 'Supplier statement with running balance (sp_supplier_ledger)' })
  ledger(@Param('id', ParseIntPipe) id: number, @Query() q: SupplierLedgerQueryDto): Promise<SupplierLedger> {
    return this.service.ledger(id, q);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get supplier (sp_supplier_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Supplier> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create supplier; code SUP001 is generated (sp_supplier_save)' })
  create(@Body() dto: SupplierSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Supplier>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update supplier (sp_supplier_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: SupplierSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Supplier>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete supplier, or mark inactive when it has purchases (sp_supplier_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
