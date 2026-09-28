import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsInt, IsNumber, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';
import { OptionalNullable, PATTERNS, ToBoolean, TrimToNull, UpperTrim } from '../../../common/dto/validators';

export class SettingsSaveDto {
  @ApiProperty({ example: 'WB Bakery' })
  @IsString()
  @MaxLength(100)
  shopName!: string;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(255) address?: string | null;

  @ApiProperty({ example: 'Tamil Nadu', description: 'State name or 2-digit GST state code' })
  @IsString()
  @MaxLength(60)
  state!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @UpperTrim()
  @OptionalNullable()
  @Matches(PATTERNS.gstin, { message: 'Enter a valid 15-character GSTIN' })
  gstin?: string | null;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(20) phone?: string | null;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsEmail() email?: string | null;

  @ApiPropertyOptional({ description: 'data: URL (uploaded) or an existing /uploads link' })
  @IsOptional()
  @OptionalNullable()
  @IsString()
  logo?: string | null;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(60) upiId?: string | null;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(255) receiptFooter?: string | null;
  @ApiPropertyOptional({ default: 10 }) @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) @Max(100) cashierMaxDiscountPct?: number;
  @ApiPropertyOptional({ default: true }) @IsOptional() @ToBoolean() @IsBoolean() allowNegativeStock?: boolean;
  @ApiPropertyOptional({ default: 4 }) @IsOptional() @IsInt() @Min(1) @Max(12) financialYearStartMonth?: number;
}
