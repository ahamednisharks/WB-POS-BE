import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsOptional, Min } from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { ToBoolean } from '../../../../common/dto/validators';

/** from / to (inherited) bound the register period; both empty = all time (opening 0, cumulative figures). */
export class StockSummaryQueryDto extends DateRangeQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) categoryId?: number;

  @ApiPropertyOptional({ enum: ['RAW', 'BOTH', 'ALL'], description: 'ALL / empty = every stock-tracked item' })
  @IsOptional()
  @IsIn(['RAW', 'BOTH', 'ALL'])
  type?: string;

  @ApiPropertyOptional({ description: 'true = only items at or below their min stock' })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  lowOnly?: boolean;
}
