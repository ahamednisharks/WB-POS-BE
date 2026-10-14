import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { IsMobile, IsMoney, IsQty, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';
import { BillPaymentDto, PAYMENT_MODES, PaymentMode } from '../../bill/dto/bill.dto';

export const PRE_ORDER_STATUSES = ['BOOKED', 'READY', 'DELIVERED', 'CANCELLED'] as const;
export const DELIVERY_TYPES = ['PICKUP', 'HOME'] as const;
export type DeliveryType = (typeof DELIVERY_TYPES)[number];

/** 2026-10-16T17:00, 2026-10-16 17:00:00 or an ISO string with an offset (converted to IST by the service). */
export const DATETIME_RE = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/;

export class PreOrderListQueryDto extends DateRangeQueryDto {
  // `status` (inherited): BOOKED | READY | DELIVERED | CANCELLED | OPEN (= BOOKED + READY) | ALL.
  // from / to (inherited) filter on the delivery date.
}

export class PreOrderLineDto {
  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Select an item' })
  @Min(1, { message: 'Select an item' })
  itemId!: number;

  @ApiProperty({ example: 1.5 })
  @IsQty()
  qty!: number;

  @ApiProperty({ example: 500, description: 'Agreed Item Price for this order; the Actual Price is read from Item Master' })
  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'Item price must be an amount with at most 2 decimals' })
  @Min(0.01, { message: 'Item price must be greater than 0' })
  rate!: number;

  @ApiPropertyOptional({ example: 'Happy Birthday Ravi, eggless' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  @MaxLength(255)
  notes?: string | null;

  @ApiPropertyOptional({ description: 'Reference photo: a data URL to upload, the existing URL to keep, null to remove' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  design?: string | null;
}

export class PreOrderSaveDto {
  @ApiProperty({ example: '9876543210' })
  @TrimToNull()
  @IsMobile()
  customerMobile!: string;

  @ApiProperty({ example: 'Ravi Kumar' })
  @TrimToNull()
  @IsString({ message: 'Customer name is required' })
  @MaxLength(80)
  customerName!: string;

  @ApiPropertyOptional({ example: '9123456780' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsMobile()
  altMobile?: string | null;

  @ApiProperty({ example: '2026-10-16T17:00:00+05:30' })
  @IsString({ message: 'Delivery date & time is required' })
  @Matches(DATETIME_RE, { message: 'Delivery date & time is invalid' })
  deliveryAt!: string;

  @ApiProperty({ enum: DELIVERY_TYPES })
  @IsIn(DELIVERY_TYPES, { message: 'Delivery type must be PICKUP or HOME' })
  deliveryType!: DeliveryType;

  @ApiPropertyOptional({ description: 'Required for HOME delivery' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  @MaxLength(255)
  deliveryAddress?: string | null;

  @ApiPropertyOptional({ default: 0, description: 'HOME delivery only; not taxed' })
  @IsOptional()
  @IsMoney()
  deliveryCharge?: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsMoney()
  discountAmount?: number;

  @ApiProperty({ type: [PreOrderLineDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one item' })
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => PreOrderLineDto)
  items!: PreOrderLineDto[];

  @ApiPropertyOptional({ type: [BillPaymentDto], description: 'New payments taken with this save (advance)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => BillPaymentDto)
  payments?: BillPaymentDto[];
}

export class PreOrderPaymentsDto {
  @ApiProperty({ type: [BillPaymentDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Payment details are required' })
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => BillPaymentDto)
  payments!: BillPaymentDto[];
}

export class PreOrderDeliverDto {
  @ApiPropertyOptional({ type: [BillPaymentDto], description: 'Balance collected now; must equal the balance due (empty when fully paid)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => BillPaymentDto)
  payments?: BillPaymentDto[];
}

export class PreOrderCancelDto {
  @ApiProperty({ example: 'Customer cancelled' })
  @IsString()
  @MinLength(1, { message: 'Cancel reason is required' })
  @MaxLength(200)
  reason!: string;

  @ApiProperty({ example: 200, description: 'Amount given back (0 .. paid); the rest is kept by the shop' })
  @IsMoney()
  refundAmount!: number;

  @ApiPropertyOptional({ enum: PAYMENT_MODES, description: 'Required when refundAmount > 0' })
  @IsOptional()
  @OptionalNullable()
  @IsIn(PAYMENT_MODES, { message: 'Refund mode must be CASH, UPI or CARD' })
  refundMode?: PaymentMode | null;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(50) referenceNo?: string | null;
}
