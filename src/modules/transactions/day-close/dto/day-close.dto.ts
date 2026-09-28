import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsMoney, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';

export class DayClosePreviewQueryDto {
  @ApiPropertyOptional({ example: '2026-09-26', description: 'Defaults to today' })
  @IsOptional()
  @IsDateOnly()
  date?: string;
}

export class DayCloseListQueryDto extends ListQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsDateOnly() from?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateOnly() to?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) cashierId?: number;
}

export class DayCloseSaveDto {
  @ApiPropertyOptional({ example: '2026-09-26', description: 'Defaults to today' })
  @IsOptional()
  @IsDateOnly()
  date?: string;

  @ApiProperty({ example: 2000 }) @IsMoney() openingCash!: number;
  @ApiProperty({ example: 18450 }) @IsMoney() countedCash!: number;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(255) remarks?: string | null;

  /** Computed by the frontend for display; the server recomputes them from transactions. */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() cashSales?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() cashRefunds?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() cashOuts?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() expectedCash?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() difference?: number;
}
