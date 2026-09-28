import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

export class ListQueryDto {
  @ApiPropertyOptional({ minimum: 1, default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  page?: number;

  /** SPs clamp to 1000 rows per page. */
  @ApiPropertyOptional({ minimum: 1, maximum: 10000, default: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10000)
  limit?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;

  /** Frontend style: field name, '-' prefix for descending (e.g. `-createdAt`). */
  @ApiPropertyOptional({ example: '-createdAt' })
  @IsOptional()
  @Matches(/^-?[A-Za-z]{1,40}$/, { message: 'sort must be a field name optionally prefixed with -' })
  sort?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^[A-Za-z]{1,40}$/)
  sortBy?: string;

  @ApiPropertyOptional({ enum: ['asc', 'desc'] })
  @IsOptional()
  @IsIn(['asc', 'desc'])
  sortDir?: 'asc' | 'desc';

  /** Masters: ACTIVE | INACTIVE | ALL. Other modules re-use it for their own status values. */
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(20)
  status?: string;
}

export class DateRangeQueryDto extends ListQueryDto {
  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'from must be YYYY-MM-DD' })
  from?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'to must be YYYY-MM-DD' })
  to?: string;
}
