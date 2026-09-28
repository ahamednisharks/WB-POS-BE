import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { MasterStatusDto } from '../../../../common/dto/status.dto';
import { ToBoolean } from '../../../../common/dto/validators';

export class UnitSaveDto extends MasterStatusDto {
  @ApiProperty({ example: 'Kilogram', maxLength: 30 })
  @IsString()
  @MinLength(1, { message: 'Unit name is required' })
  @MaxLength(30)
  name!: string;

  @ApiProperty({ example: 'KG', maxLength: 5 })
  @IsString()
  @MinLength(1, { message: 'Short code is required' })
  @MaxLength(5, { message: 'Short code must be at most 5 characters' })
  shortCode!: string;

  @ApiPropertyOptional({ default: false, description: 'true for weight/volume units (0.500 kg)' })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  allowDecimal?: boolean;
}
