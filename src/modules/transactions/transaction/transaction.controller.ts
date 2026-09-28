import { Controller, Get, Query, StreamableFile } from '@nestjs/common';
import { ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult } from '../../../common/utils/api-result';
import { TransactionExportQueryDto, TransactionListQueryDto } from './dto/transaction.dto';
import { Transaction } from './transaction.repository';
import { TransactionService } from './transaction.service';

@ApiTags('Transactions')
@Controller('transactions')
export class TransactionController {
  constructor(private readonly service: TransactionService) {}

  @Get()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Till transactions + summary (sp_transaction_list). Cashiers: own, today only' })
  list(@Query() q: TransactionListQueryDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Transaction[]>> {
    return this.service.list(q, user);
  }

  @Get('export')
  @Roles('ADMIN')
  @ApiProduces('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/pdf')
  @ApiOperation({ summary: 'Download transactions as Excel or PDF (sp_transaction_export)' })
  export(@Query() q: TransactionExportQueryDto, @CurrentUser() user: AuthUser): Promise<StreamableFile> {
    return this.service.export(q, user);
  }
}
