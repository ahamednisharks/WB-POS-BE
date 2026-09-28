import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsIn, IsInt, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsGst, IsMoney, IsQty, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';

export const PO_STATUSES = ['DRAFT', 'SENT', 'PARTIAL', 'RECEIVED', 'CANCELLED'] as const;

export class PoListQueryDto extends DateRangeQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) supplierId?: number;

  @ApiPropertyOptional({ enum: [...PO_STATUSES, 'OPEN', 'ALL'], description: 'Alias of status; OPEN = SENT + PARTIAL' })
  @IsOptional()
  @IsIn([...PO_STATUSES, 'OPEN', 'ALL'])
  poStatus?: string;
}

export class PoOpenQueryDto {
  @ApiProperty({ example: '1' })
  @IsInt()
  @Min(1)
  supplierId!: number;
}

export class PoItemDto {
  @ApiProperty({ example: '3' })
  @IsInt({ message: 'Select an item' })
  @Min(1, { message: 'Select an item' })
  itemId!: number;

  @ApiProperty({ example: 50 }) @IsQty() qty!: number;
  @ApiProperty({ example: 42, description: 'Rate before GST' }) @IsMoney() rate!: number;
  @ApiPropertyOptional({ description: 'Defaults to the item GST' }) @IsOptional() @OptionalNullable() @IsGst() gstPercent?: number | null;

  // Display fields the form may echo back; ignored.
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() itemName?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() unitCode?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() receivedQty?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() amount?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() gstAmount?: number;
}

export class PoSaveDto {
  @ApiProperty({ example: '2026-09-26' }) @IsDateOnly() poDate!: string;

  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Supplier is required' })
  @Min(1, { message: 'Supplier is required' })
  supplierId!: number;

  @ApiPropertyOptional({ nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() expectedDate?: string | null;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(500) notes?: string | null;

  @ApiProperty({ type: [PoItemDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one item' })
  @ValidateNested({ each: true })
  @Type(() => PoItemDto)
  items!: PoItemDto[];

  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsMoney() otherCharges?: number;

  @ApiPropertyOptional({ enum: ['DRAFT', 'SENT', 'SEND'], default: 'DRAFT', description: 'SENT / SEND = send to supplier' })
  @IsOptional()
  @IsIn(['DRAFT', 'SENT', 'SEND'])
  status?: 'DRAFT' | 'SENT' | 'SEND';
}

export class PoCancelDto {
  @ApiProperty()
  @IsString()
  @MinLength(1, { message: 'Cancel reason is required' })
  @MaxLength(200)
  reason!: string;
}
