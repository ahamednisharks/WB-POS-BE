import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsIn, IsInt, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsGst, IsMoney, IsQty, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';
import { UploadedFileDto } from '../../../employee/employee/dto/employee.dto';

export const SUPPLIER_PAY_MODES = ['CASH', 'BANK', 'UPI', 'CHEQUE'] as const;
export type SupplierPayMode = (typeof SUPPLIER_PAY_MODES)[number];

export class PeListQueryDto extends DateRangeQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) supplierId?: number;

  @ApiPropertyOptional({ enum: ['UNPAID', 'PARTLY_PAID', 'PARTIAL', 'PAID', 'ALL'] })
  @IsOptional()
  @IsIn(['UNPAID', 'PARTLY_PAID', 'PARTIAL', 'PAID', 'ALL'])
  paymentStatus?: string;
}

export class PeItemDto {
  @ApiProperty({ example: '3' })
  @IsInt({ message: 'Select an item' })
  @Min(1, { message: 'Select an item' })
  itemId!: number;

  @ApiPropertyOptional({ nullable: true }) @IsOptional() @OptionalNullable() @IsNumber({ maxDecimalPlaces: 3 }) @Min(0) orderedQty?: number | null;
  @ApiProperty({ example: 30 }) @IsQty() receivedQty!: number;
  @ApiProperty({ example: 42, description: 'Rate before GST' }) @IsMoney() rate!: number;
  @ApiPropertyOptional({ description: 'Defaults to the item GST' }) @IsOptional() @OptionalNullable() @IsGst() gstPercent?: number | null;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() expiryDate?: string | null;

  // Display fields the form may echo back; ignored.
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() itemName?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() unitCode?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() amount?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() gstAmount?: number;
}

export class PeSaveDto {
  @ApiProperty({ example: '2026-09-26' }) @IsDateOnly() peDate!: string;

  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Supplier is required' })
  @Min(1, { message: 'Supplier is required' })
  supplierId!: number;

  @ApiPropertyOptional({ nullable: true }) @IsOptional() @OptionalNullable() @IsInt() @Min(1) poId?: number | null;

  @ApiProperty({ example: 'INV-1001' })
  @IsString()
  @MinLength(1, { message: 'Supplier invoice no. is required' })
  @MaxLength(40)
  invoiceNo!: string;

  @ApiProperty({ example: '2026-09-26' }) @IsDateOnly() invoiceDate!: string;

  @ApiPropertyOptional({ type: UploadedFileDto, nullable: true, description: 'PDF / JPG / PNG, up to MAX_INVOICE_MB' })
  @IsOptional()
  @OptionalNullable()
  @ValidateNested()
  @Type(() => UploadedFileDto)
  invoiceCopy?: UploadedFileDto | null;

  @ApiProperty({ type: [PeItemDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one item' })
  @ValidateNested({ each: true })
  @Type(() => PeItemDto)
  items!: PeItemDto[];

  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsMoney() discount?: number;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsMoney() otherCharges?: number;
  @ApiPropertyOptional({ default: 0, description: 'Paid while saving (new entries only)' }) @IsOptional() @IsMoney() paidNow?: number;
  @ApiPropertyOptional({ enum: SUPPLIER_PAY_MODES, nullable: true }) @IsOptional() @OptionalNullable() @IsIn(SUPPLIER_PAY_MODES) paymentMode?: SupplierPayMode | null;
}

export class PePaymentDto {
  @ApiProperty({ example: 500 }) @IsMoney() amount!: number;

  @ApiProperty({ enum: SUPPLIER_PAY_MODES })
  @IsIn(SUPPLIER_PAY_MODES, { message: 'Payment mode must be CASH, BANK, UPI or CHEQUE' })
  mode!: SupplierPayMode;

  @ApiPropertyOptional({ example: '2026-09-26', description: 'Frontend field name' }) @IsOptional() @IsDateOnly() date?: string;
  @ApiPropertyOptional({ example: '2026-09-26', description: 'Alias of date' }) @IsOptional() @IsDateOnly() paymentDate?: string;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(50) referenceNo?: string | null;
}
