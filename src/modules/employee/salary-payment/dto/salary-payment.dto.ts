import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsMoney, IsMonth, OptionalNullable, TrimToNull } from '../../../../common/dto/validators';

export const PAY_STATUSES = ['PENDING', 'PAID'] as const;
export const SALARY_PAY_MODES = ['CASH', 'BANK', 'UPI'] as const;
export type SalaryPayMode = (typeof SALARY_PAY_MODES)[number];

export class SalaryPaymentListQueryDto extends ListQueryDto {
  @ApiPropertyOptional({ example: '2026-09' }) @IsOptional() @IsMonth() month?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) employeeId?: number;
  @ApiPropertyOptional({ enum: [...PAY_STATUSES, 'ALL'], description: 'Alias of status' }) @IsOptional() @IsIn([...PAY_STATUSES, 'ALL']) payStatus?: string;
}

export class SalaryCalculateQueryDto {
  @ApiProperty({ example: '2' }) @IsInt() @Min(1) employeeId!: number;
  @ApiProperty({ example: '2026-09' }) @IsMonth() month!: string;
  @ApiProperty({ example: 26 }) @IsNumber({ maxDecimalPlaces: 1 }) @Min(1) @Max(31) workingDays!: number;
  @ApiProperty({ example: 25.5 }) @IsNumber({ maxDecimalPlaces: 1 }) @Min(0) @Max(31) daysPresent!: number;
}

export class SalaryPaymentSaveDto {
  @ApiProperty({ example: '2026-09' })
  @IsMonth()
  month!: string;

  @ApiProperty({ example: '2' })
  @IsInt({ message: 'Employee is required' })
  @Min(1, { message: 'Employee is required' })
  employeeId!: number;

  @ApiProperty({ example: 26 }) @IsNumber({ maxDecimalPlaces: 1 }) @Min(1) @Max(31) workingDays!: number;
  @ApiProperty({ example: 26 }) @IsNumber({ maxDecimalPlaces: 1 }) @Min(0) @Max(31) daysPresent!: number;

  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsMoney() bonus?: number;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsMoney() advanceDeduction?: number;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsMoney() otherDeductions?: number;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(200) deductionReason?: string | null;

  @ApiPropertyOptional({ enum: PAY_STATUSES, default: 'PENDING', description: 'PAID also marks it paid' })
  @IsOptional()
  @IsIn(PAY_STATUSES)
  status?: (typeof PAY_STATUSES)[number];

  @ApiPropertyOptional({ nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() paymentDate?: string | null;
  @ApiPropertyOptional({ enum: SALARY_PAY_MODES, nullable: true }) @IsOptional() @OptionalNullable() @IsIn(SALARY_PAY_MODES) paymentMode?: SalaryPayMode | null;

  /** Computed by the server (sp_salary_payment_compute); accepted and ignored. */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() gross?: number;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsNumber() net?: number;
}

export class MarkPaidDto {
  @ApiProperty({ example: '2026-09-30' }) @IsDateOnly() paymentDate!: string;
  @ApiProperty({ enum: SALARY_PAY_MODES }) @IsIn(SALARY_PAY_MODES, { message: 'Payment mode must be CASH, BANK or UPI' }) paymentMode!: SalaryPayMode;
}
