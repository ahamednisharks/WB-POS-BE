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
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { DateRangeQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsQty, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';

/** Why raw material left the warehouse. PRODUCTION = sent to the production unit (the normal case). */
export const ISSUE_REASONS = ['PRODUCTION', 'WASTAGE', 'EXPIRED', 'DAMAGED', 'OTHER'] as const;
export type IssueReason = (typeof ISSUE_REASONS)[number];

export const ISSUE_STATUSES = ['POSTED', 'CANCELLED'] as const;
export type IssueStatus = (typeof ISSUE_STATUSES)[number];

export class StockIssueListQueryDto extends DateRangeQueryDto {
  /** Issues that have at least one line with this reason. */
  @ApiPropertyOptional({ enum: [...ISSUE_REASONS, 'ALL'] })
  @IsOptional()
  @IsIn([...ISSUE_REASONS, 'ALL'])
  reason?: string;

  // status (inherited): POSTED | CANCELLED | ALL; from / to filter the issue date.
}

export class StockIssueItemDto {
  @ApiProperty({ example: '31' })
  @IsInt({ message: 'Select an item' })
  @Min(1, { message: 'Select an item' })
  itemId!: number;

  @ApiProperty({ example: 2.5 }) @IsQty() qty!: number;

  @ApiProperty({ enum: ISSUE_REASONS, default: 'PRODUCTION' })
  @IsIn(ISSUE_REASONS, { message: 'Reason must be Production, Wastage, Expired, Damaged or Other' })
  reason!: IssueReason;

  @ApiPropertyOptional({ nullable: true, description: 'Required when the reason is OTHER' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  @MaxLength(200)
  remarks?: string | null;

  // Display fields the form may echo back; ignored.
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() itemName?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() unitCode?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() rate?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() amount?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() currentStock?: number;
}

export class StockIssueSaveDto {
  @ApiProperty({ example: '2026-10-16' }) @IsDateOnly() issueDate!: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  @MaxLength(200)
  remarks?: string | null;

  @ApiProperty({ type: [StockIssueItemDto], description: 'One line per item' })
  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one item' })
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => StockIssueItemDto)
  items!: StockIssueItemDto[];
}

export class StockIssueCancelDto {
  @ApiProperty({ example: 'Entered on the wrong item' })
  @IsString()
  @MinLength(1, { message: 'Cancel reason is required' })
  @MaxLength(200)
  reason!: string;
}
