import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { PATTERNS, ToBoolean } from '../../../common/dto/validators';

export class LoginDto {
  @ApiProperty({ example: 'admin' })
  @Matches(PATTERNS.username, { message: 'Username must be 3-30 characters with no spaces' })
  username!: string;

  @ApiProperty({ example: 'admin123' })
  @IsString()
  @MinLength(1, { message: 'Password is required' })
  @MaxLength(100)
  password!: string;

  @ApiPropertyOptional({ default: false, description: 'true = 7 day token, false = 8 hour token' })
  @IsOptional()
  @ToBoolean()
  @IsBoolean()
  rememberMe?: boolean;
}

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @MinLength(1, { message: 'Current password is required' })
  currentPassword!: string;

  @ApiProperty({ minLength: 6 })
  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters' })
  @MaxLength(100)
  newPassword!: string;
}
