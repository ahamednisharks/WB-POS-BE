import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, Min } from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';

export const TXN_TYPES = ['PAYMENT', 'REFUND', 'CASH_OUT'] as const;
export const TXN_MODES = ['CASH', 'UPI', 'CARD', 'BANK', 'CHEQUE'] as const;

export class TransactionListQueryDto extends DateRangeQueryDto {
  @ApiPropertyOptional({ enum: [...TXN_MODES, 'ALL'] }) @IsOptional() @IsIn([...TXN_MODES, 'ALL']) mode?: string;
  @ApiPropertyOptional({ enum: [...TXN_TYPES, 'ALL'] }) @IsOptional() @IsIn([...TXN_TYPES, 'ALL']) type?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) cashierId?: number;
}

export class TransactionExportQueryDto extends TransactionListQueryDto {
  @ApiPropertyOptional({ enum: ['xlsx', 'pdf'], default: 'xlsx' })
  @IsOptional()
  @IsIn(['xlsx', 'pdf'])
  format?: 'xlsx' | 'pdf';
}
