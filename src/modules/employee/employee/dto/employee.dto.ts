import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsEmail, IsIn, IsInt, IsNumber, IsOptional, IsString, Matches, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { IsDateOnly, IsMobile, OptionalNullable, PATTERNS, TrimToNull, UpperTrim } from '../../../../common/dto/validators';

export const GENDERS = ['MALE', 'FEMALE', 'OTHER'] as const;
export const EMP_STATUSES = ['ACTIVE', 'RESIGNED'] as const;
export type EmployeeStatus = (typeof EMP_STATUSES)[number];

/** Masked values returned by the list endpoint (e.g. XXXXXXXX1234) are accepted and mean "unchanged". */
const MASKED = /^X+\d{4}$/;

export class EmployeeListQueryDto extends ListQueryDto {
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) employeeTypeId?: number;

  @ApiPropertyOptional({ enum: [...EMP_STATUSES, 'ALL'], description: 'Alias of status' })
  @IsOptional()
  @IsIn([...EMP_STATUSES, 'ALL'])
  empStatus?: string;
}

/** File as the frontend sends it: data: URL on upload, or the link it received earlier. */
export class UploadedFileDto {
  @ApiProperty() @IsString() @MaxLength(150) name!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100) type?: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber() size?: number;
  @ApiProperty({ description: 'data: URL (new file) or the existing link' }) @IsString() dataUrl!: string;
}

export class EmployeeSaveDto {
  @ApiPropertyOptional({ description: 'data: URL (JPG/PNG <= 1 MB) or an existing link', nullable: true })
  @IsOptional()
  @OptionalNullable()
  @IsString()
  photo?: string | null;

  @ApiProperty({ example: 'Priya Sundaram' })
  @IsString()
  @MinLength(1, { message: 'Full name is required' })
  @MaxLength(80)
  fullName!: string;

  @ApiProperty({ example: '1' })
  @IsInt({ message: 'Employee type is required' })
  @Min(1, { message: 'Employee type is required' })
  employeeTypeId!: number;

  @ApiProperty({ example: '9876500001' })
  @IsMobile()
  mobile!: string;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsMobile() altMobile?: string | null;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsEmail({}, { message: 'Enter a valid email' }) email?: string | null;

  @ApiProperty({ enum: GENDERS })
  @IsIn(GENDERS, { message: 'Select a gender' })
  gender!: (typeof GENDERS)[number];

  @ApiPropertyOptional({ example: '1995-05-10', nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() dob?: string | null;

  @ApiProperty({ example: '2024-01-15' })
  @IsDateOnly()
  joiningDate!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1, { message: 'Address is required' })
  @MaxLength(255)
  address!: string;

  @ApiPropertyOptional({ example: '123412341234', description: '12 digits; stored AES-256-GCM encrypted' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @Matches(new RegExp(`${PATTERNS.aadhaar.source}|${MASKED.source}`), { message: 'Aadhaar must be 12 digits' })
  aadhaar?: string | null;

  @ApiPropertyOptional({ type: UploadedFileDto, nullable: true })
  @IsOptional()
  @OptionalNullable()
  @ValidateNested()
  @Type(() => UploadedFileDto)
  idProof?: UploadedFileDto | null;

  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsString() @MaxLength(80) emergencyName?: string | null;
  @ApiPropertyOptional() @IsOptional() @TrimToNull() @OptionalNullable() @IsMobile() emergencyMobile?: string | null;

  @ApiPropertyOptional({ description: '9-18 digits; stored AES-256-GCM encrypted' })
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @Matches(new RegExp(`${PATTERNS.bankAccount.source}|${MASKED.source}`), { message: 'Account number must be 9 to 18 digits' })
  bankAccount?: string | null;

  @ApiPropertyOptional({ example: 'SBIN0001234' })
  @IsOptional()
  @UpperTrim()
  @OptionalNullable()
  @Matches(PATTERNS.ifsc, { message: 'Enter a valid IFSC code' })
  ifsc?: string | null;

  @ApiPropertyOptional({ enum: EMP_STATUSES, default: 'ACTIVE' })
  @IsOptional()
  @IsIn(EMP_STATUSES)
  status?: EmployeeStatus;

  @ApiPropertyOptional({ nullable: true }) @IsOptional() @TrimToNull() @OptionalNullable() @IsDateOnly() resignDate?: string | null;
}

export function isMasked(value: string | null | undefined): boolean {
  return !!value && MASKED.test(value);
}
