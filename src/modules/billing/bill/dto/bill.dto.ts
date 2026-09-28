import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { IsMobile, IsQty, OptionalNullable, ToBoolean, TrimToNull } from '../../../../common/dto/validators';

export const BILL_STATUSES = ['HELD', 'COMPLETED', 'CANCELLED'] as const;
export const PAYMENT_MODES = ['CASH', 'UPI', 'CARD'] as const;
export type PaymentMode = (typeof PAYMENT_MODES)[number];

/**
 * One cart row. Accepts the spec shape `{ itemId | comboId, qty }` and the frontend shape
 * `{ kind: 'ITEM' | 'COMBO', refId, qty, ...display fields }`. Prices sent by the client are ignored.
 */
export class BillLineDto {
  @ApiPropertyOptional() @IsOptional() @OptionalNullable() @IsInt() @Min(1) itemId?: number | null;
  @ApiPropertyOptional() @IsOptional() @OptionalNullable() @IsInt() @Min(1) comboId?: number | null;

  @ApiPropertyOptional({ enum: ['ITEM', 'COMBO'] }) @IsOptional() @IsIn(['ITEM', 'COMBO']) kind?: 'ITEM' | 'COMBO';
  @ApiPropertyOptional({ description: 'itemId or comboId depending on kind' }) @IsOptional() @IsInt() @Min(1) refId?: number;

  @ApiProperty({ example: 2 })
  @IsQty()
  qty!: number;

  // Display-only fields the billing screen sends along; ignored by the server.
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() code?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() name?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() unitCode?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsBoolean() allowDecimal?: boolean;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() rate?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() gstPercent?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsBoolean() priceIncludesGst?: boolean;
}

export class BillPaymentDto {
  @ApiProperty({ enum: PAYMENT_MODES })
  @IsIn(PAYMENT_MODES, { message: 'Payment mode must be CASH, UPI or CARD' })
  mode!: PaymentMode;

  @ApiProperty({ example: 250 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount!: number;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(50) referenceNo?: string | null;
  @ApiPropertyOptional({ description: 'Alias of referenceNo' }) @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(50) reference?: string | null;
  @ApiPropertyOptional({ description: 'Cash handed over (CASH only)' }) @IsOptional() @OptionalNullable() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) cashReceived?: number | null;
}

export class BillSaveDto {
  @ApiPropertyOptional({ description: 'Device-generated UUID; resending the same one returns the existing bill' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsUUID('all', { message: 'clientRef must be a UUID' })
  clientRef?: string | null;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(50) deviceId?: string | null;

  @ApiPropertyOptional({ description: 'Frontend: id of the HELD bill being updated / completed' })
  @IsOptional()
  @OptionalNullable()
  // `number | null` emits design:type Object, so implicit conversion skips it — ids arrive as strings.
  @Type(() => Number)
  @IsInt()
  @Min(1)
  heldBillId?: number | null;

  @ApiProperty({ enum: ['HELD', 'COMPLETED'] })
  @IsIn(['HELD', 'COMPLETED'], { message: 'Status must be HELD or COMPLETED' })
  status!: 'HELD' | 'COMPLETED';

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsMobile() customerMobile?: string | null;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(80) customerName?: string | null;

  @ApiPropertyOptional({ enum: ['AMOUNT', 'PERCENT'], default: 'AMOUNT' })
  @IsOptional()
  @IsIn(['AMOUNT', 'PERCENT'])
  discountType?: 'AMOUNT' | 'PERCENT';

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  discountValue?: number;

  @ApiPropertyOptional({ type: [BillLineDto], description: 'Spec shape' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => BillLineDto)
  items?: BillLineDto[];

  @ApiPropertyOptional({ type: [BillLineDto], description: 'Frontend shape (kind + refId)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => BillLineDto)
  lines?: BillLineDto[];

  @ApiPropertyOptional({ type: [BillPaymentDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => BillPaymentDto)
  payments?: BillPaymentDto[];

  @ApiPropertyOptional({ description: 'Frontend: cash handed over, applied to the CASH payment' })
  @IsOptional()
  @OptionalNullable()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  cashReceived?: number | null;

  /** Computed by the server; accepted and ignored. */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @OptionalNullable() @IsNumber() changeReturned?: number | null;
}

export class BillSyncDto {
  @ApiProperty({ type: [BillSaveDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => BillSaveDto)
  bills!: BillSaveDto[];
}

export class BillListQueryDto extends DateRangeQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) cashierId?: number;
  @ApiPropertyOptional({ enum: [...PAYMENT_MODES, 'SPLIT', 'ALL'] }) @IsOptional() @IsIn([...PAYMENT_MODES, 'SPLIT', 'ALL']) paymentMode?: string;
}

export class BillCancelDto {
  @ApiProperty({ example: 'Customer returned' })
  @IsString()
  @MinLength(1, { message: 'Cancel reason is required' })
  @MaxLength(200)
  reason!: string;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(200) remarks?: string | null;
}

export class ReceiptQueryDto {
  @ApiPropertyOptional({ description: 'true = reprint (marked DUPLICATE)' })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  duplicate?: boolean;
}
