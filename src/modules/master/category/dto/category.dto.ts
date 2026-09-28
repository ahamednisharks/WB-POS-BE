import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';
import { MasterStatusDto } from '../../../../common/dto/status.dto';
import { OptionalNullable } from '../../../../common/dto/validators';

export class CategorySaveDto extends MasterStatusDto {
  @ApiProperty({ example: 'Cakes', maxLength: 50 })
  @IsString()
  @MinLength(1, { message: 'Category name is required' })
  @MaxLength(50)
  name!: string;

  @ApiPropertyOptional({ description: 'data: URL (JPG/PNG <= 1 MB) or an existing /uploads link', nullable: true })
  @IsOptional()
  @OptionalNullable()
  @IsString()
  image?: string | null;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  displayOrder?: number;
}
