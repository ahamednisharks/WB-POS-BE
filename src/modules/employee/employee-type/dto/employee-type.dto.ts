import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { ListQueryDto } from '../../../../common/dto/list-query.dto';
import { MasterStatusDto } from '../../../../common/dto/status.dto';
import { OptionalNullable, ToBoolean, TrimToNull } from '../../../../common/dto/validators';

export class EmployeeTypeListQueryDto extends ListQueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  canLogin?: boolean;
}

export class EmployeeTypeSaveDto extends MasterStatusDto {
  @ApiProperty({ example: 'Cashier' })
  @IsString()
  @MinLength(1, { message: 'Type name is required' })
  @MaxLength(40)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @TrimToNull()
  @OptionalNullable()
  @IsString()
  @MaxLength(200)
  description?: string | null;

  @ApiPropertyOptional({ default: false, description: 'Employees of this type may be given a login' })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  canLogin?: boolean;
}
