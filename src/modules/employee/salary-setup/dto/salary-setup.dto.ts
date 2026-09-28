import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsMoney, IsMonth } from '../../../../common/dto/validators';

export const SALARY_TYPES = ['MONTHLY', 'DAILY'] as const;
export type SalaryType = (typeof SALARY_TYPES)[number];

export class SalarySetupListQueryDto extends ListQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) employeeId?: number;
  @ApiPropertyOptional({ enum: [...SALARY_TYPES, 'ALL'] }) @IsOptional() @IsIn([...SALARY_TYPES, 'ALL']) salaryType?: string;
}

export class SalarySetupCurrentQueryDto {
  @ApiPropertyOptional({ example: '2026-09', description: 'Defaults to the current month' })
  @IsOptional()
  @IsMonth()
  month?: string;
}

export class SalarySetupSaveDto {
  @ApiProperty({ example: '2' })
  @IsInt({ message: 'Employee is required' })
  @Min(1, { message: 'Employee is required' })
  employeeId!: number;

  @ApiProperty({ enum: SALARY_TYPES })
  @IsIn(SALARY_TYPES, { message: 'Salary type must be MONTHLY or DAILY' })
  salaryType!: SalaryType;

  @ApiProperty({ example: 18000, description: 'Per month (MONTHLY) or per day (DAILY)' })
  @IsMoney()
  basicSalary!: number;

  @ApiPropertyOptional({ example: 3000, default: 0 })
  @IsOptional()
  @IsMoney()
  allowances?: number;

  @ApiProperty({ example: '2026-08-01' })
  @IsDateOnly()
  effectiveFrom!: string;

  /** Echoed back by the frontend form; ignored. */
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() empCode?: string;
  @ApiPropertyOptional({ readOnly: true }) @IsOptional() @IsString() employeeName?: string;
}
