import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsMoney, OptionalNullable, ToBoolean, TrimToNull } from '../../../../common/dto/validators';

export class AdvanceListQueryDto extends DateRangeQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) employeeId?: number;

  @ApiPropertyOptional({ description: 'true = only advances with a balance left' })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  pendingOnly?: boolean;
}

export class AdvanceSaveDto {
  @ApiProperty({ example: '2' })
  @IsInt({ message: 'Employee is required' })
  @Min(1, { message: 'Employee is required' })
  employeeId!: number;

  @ApiProperty({ example: '2026-09-01' })
  @IsDateOnly()
  advanceDate!: string;

  @ApiProperty({ example: 2000 })
  @IsMoney()
  amount!: number;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(200) remarks?: string | null;
}
