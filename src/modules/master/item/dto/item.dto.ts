import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsNumber, IsOptional, IsString, Matches, MaxLength, Min, MinLength } from 'class-validator';
import { DateRangeQueryDto, ListQueryDto } from '../../../../common/dto/list-query.dto';
import { MasterStatusDto } from '../../../../common/dto/status.dto';
import { IsGst, IsMoney, OptionalNullable, PATTERNS, ToBoolean, TrimToNull, UpperTrim } from '../../../../common/dto/validators';

export const ITEM_TYPES = ['SALE', 'RAW', 'BOTH'] as const;
export type ItemType = (typeof ITEM_TYPES)[number];

export class ItemListQueryDto extends ListQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) categoryId?: number;

  @ApiPropertyOptional({ enum: [...ITEM_TYPES, 'ALL'] })
  @IsOptional()
  @IsIn([...ITEM_TYPES, 'ALL'])
  type?: string;

  @ApiPropertyOptional({ enum: ITEM_TYPES, description: 'Alias of type' })
  @IsOptional()
  @IsIn([...ITEM_TYPES, 'ALL'])
  itemType?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(40) barcode?: string;

  @ApiPropertyOptional({ description: 'true = SALE and BOTH items only' })
  @IsOptional() @ToBoolean() @IsBoolean() saleable?: boolean;

  @ApiPropertyOptional({ description: 'true = RAW and BOTH items only' })
  @IsOptional() @ToBoolean() @IsBoolean() purchasable?: boolean;

  @ApiPropertyOptional({ description: 'true = stock-tracked items at or below minimum stock' })
  @IsOptional() @ToBoolean() @IsBoolean() lowStock?: boolean;
}

export class ItemDropdownQueryDto {
  @ApiPropertyOptional({ enum: ITEM_TYPES })
  @IsOptional()
  @IsIn(ITEM_TYPES)
  type?: ItemType;
}

export class StockLedgerQueryDto extends DateRangeQueryDto {}

export class StockAdjustDto {
  @ApiProperty({ enum: ['OPENING', 'ADJUST'], description: 'OPENING = opening stock, ADJUST = production / wastage / count correction' })
  @IsIn(['OPENING', 'ADJUST'])
  type!: 'OPENING' | 'ADJUST';

  @ApiProperty({ example: 24, description: 'Positive adds stock, negative removes it' })
  @IsNumber({ maxDecimalPlaces: 3 })
  qty!: number;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(200) remarks?: string | null;
}

export class ItemSaveDto extends MasterStatusDto {
  @ApiPropertyOptional({ example: 'ITM0001', description: 'Blank = next ITM number' })
  @IsOptional()
  @UpperTrim()
  @OptionalNullable()
  @IsString()
  @MaxLength(20)
  code?: string | null;

  @ApiProperty({ example: 'Black Forest Cake (500 g)' })
  @IsString()
  @MinLength(1, { message: 'Item name is required' })
  @MaxLength(60)
  name!: string;

  @ApiProperty({ enum: ITEM_TYPES })
  @IsIn(ITEM_TYPES, { message: 'Item type must be SALE, RAW or BOTH' })
  type!: ItemType;

  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Category is required' })
  @Min(1, { message: 'Category is required' })
  categoryId!: number;

  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Unit is required' })
  @Min(1, { message: 'Unit is required' })
  unitId!: number;

  @ApiPropertyOptional({ example: 450 })
  @IsOptional()
  @IsMoney()
  sellingPrice?: number;

  @ApiProperty({ enum: [0, 5, 12, 18, 28] })
  @IsGst()
  gstPercent!: number;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  priceIncludesGst?: boolean;

  @ApiPropertyOptional({ example: '1905' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @Matches(PATTERNS.hsn, { message: 'HSN code must be 4 to 8 digits' })
  hsnCode?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  @MaxLength(40)
  barcode?: string | null;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 3 })
  @Min(0)
  minStock?: number;

  @ApiPropertyOptional({ description: 'data: URL (JPG/PNG <= 1 MB) or an existing /uploads link', nullable: true })
  @IsOptional()
  @OptionalNullable()
  @IsString()
  image?: string | null;
}
