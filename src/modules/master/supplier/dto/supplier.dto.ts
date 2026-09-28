import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsInt, IsNumber, IsOptional, IsString, Matches, MaxLength, Min, MinLength } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { MasterStatusDto } from '../../../../common/dto/status.dto';
import { IsDateOnly, IsMobile, OptionalNullable, PATTERNS, TrimToNull, UpperTrim } from '../../../../common/dto/validators';

export class SupplierListQueryDto extends ListQueryDto {
  @ApiPropertyOptional({ example: 'Tamil Nadu', description: 'State name or GST state code' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  state?: string;
}

export class SupplierLedgerQueryDto {
  @ApiPropertyOptional({ example: '2026-04-01' }) @IsOptional() @IsDateOnly() from?: string;
  @ApiPropertyOptional({ example: '2026-09-30' }) @IsOptional() @IsDateOnly() to?: string;
}

export class SupplierSaveDto extends MasterStatusDto {
  @ApiProperty({ example: 'Sri Balaji Flour Mills' })
  @IsString()
  @MinLength(1, { message: 'Supplier name is required' })
  @MaxLength(80)
  name!: string;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(80) contactPerson?: string | null;

  @ApiProperty({ example: '9840011111' })
  @IsMobile()
  mobile!: string;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsEmail({}, { message: 'Enter a valid email' }) email?: string | null;

  @ApiProperty()
  @IsString()
  @MinLength(1, { message: 'Address is required' })
  @MaxLength(255)
  address!: string;

  @ApiProperty({ example: 'Tamil Nadu', description: 'State name (or GST state code)' })
  @IsString()
  @MinLength(1, { message: 'State is required' })
  @MaxLength(60)
  state!: string;

  @ApiPropertyOptional({ example: '33AABCS1234F1Z5' })
  @IsOptional()
  @UpperTrim()
  @OptionalNullable()
  @Matches(PATTERNS.gstin, { message: 'Enter a valid 15-character GSTIN' })
  gstin?: string | null;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  openingBalance?: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  paymentTermsDays?: number;

  /** Read-only fields the edit form may echo back. */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() code?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() currentBalance?: number;
}
