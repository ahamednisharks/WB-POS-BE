import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Matches, MaxLength, Min, MinLength } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { PATTERNS, ToBoolean } from '../../../../common/dto/validators';

export const ROLES = ['ADMIN', 'CASHIER'] as const;
export const LOGIN_STATUSES = ['ACTIVE', 'BLOCKED'] as const;
export type LoginStatus = (typeof LOGIN_STATUSES)[number];

export class LoginListQueryDto extends ListQueryDto {
  @ApiPropertyOptional({ enum: [...ROLES, 'ALL'] }) @IsOptional() @IsIn([...ROLES, 'ALL']) role?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) employeeId?: number;
}

export class LoginUpdateDto {
  @ApiProperty({ example: 'priya' })
  @Matches(PATTERNS.username, { message: 'Username must be 3-30 characters with no spaces' })
  username!: string;

  @ApiProperty({ enum: ROLES })
  @IsIn(ROLES, { message: 'Role must be ADMIN or CASHIER' })
  role!: (typeof ROLES)[number];

  @ApiPropertyOptional({ enum: LOGIN_STATUSES, default: 'ACTIVE' })
  @IsOptional()
  @IsIn(LOGIN_STATUSES)
  status?: LoginStatus;
}

export class LoginCreateDto extends LoginUpdateDto {
  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Employee is required' })
  @Min(1, { message: 'Employee is required' })
  employeeId!: number;

  @ApiProperty({ minLength: 6 })
  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters' })
  @MaxLength(100)
  password!: string;
}

export class ResetPasswordDto {
  @ApiProperty({ minLength: 6 })
  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters' })
  @MaxLength(100)
  password!: string;
}

export class BlockDto {
  @ApiProperty()
  @ToBoolean()
  @IsBoolean()
  blocked!: boolean;
}

export function loginStatusFlag(status: LoginStatus | string | undefined): number | null {
  if (status === 'ACTIVE') return 1;
  if (status === 'BLOCKED') return 0;
  return null;
}
