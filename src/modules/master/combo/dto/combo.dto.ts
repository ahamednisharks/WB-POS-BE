import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsInt, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { MasterStatusDto } from '../../../../common/dto/status.dto';
import { IsDateOnly, IsGst, IsMoney, IsQty, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';

export class ComboListQueryDto extends ListQueryDto {
  @ApiPropertyOptional({ example: '2026-09-26', description: 'Only combos that are active and valid on this date' })
  @IsOptional()
  @IsDateOnly()
  activeOn?: string;
}

export class ComboItemDto {
  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Select an item' })
  @Min(1, { message: 'Select an item' })
  itemId!: number;

  @ApiProperty({ example: 1 })
  @IsQty()
  qty!: number;

  /** Sent back by the frontend form; ignored (the SP snapshots the current selling price). */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() itemName?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() price?: number;
}

export class ComboSaveDto extends MasterStatusDto {
  @ApiProperty({ example: 'Tea Time Combo' })
  @IsString()
  @MinLength(1, { message: 'Combo name is required' })
  @MaxLength(60)
  name!: string;

  @ApiProperty({ type: [ComboItemDto] })
  @IsArray()
  @ArrayMinSize(2, { message: 'A combo needs at least 2 items' })
  @ValidateNested({ each: true })
  @Type(() => ComboItemDto)
  items!: ComboItemDto[];

  @ApiProperty({ example: 99 })
  @IsMoney()
  comboPrice!: number;

  @ApiPropertyOptional({ description: 'Blank = highest GST among the items', nullable: true })
  @IsOptional()
  @OptionalNullable()
  @IsGst()
  gstPercent?: number | null;

  @ApiPropertyOptional({ nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() validFrom?: string | null;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() validTo?: string | null;

  @ApiPropertyOptional({ description: 'data: URL or an existing /uploads link', nullable: true })
  @IsOptional()
  @OptionalNullable()
  @IsString()
  image?: string | null;

  /** Computed by the server; accepted and ignored. */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() actualPrice?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() savings?: number;
}
