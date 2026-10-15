import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
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

/** Colour themes offered in the top bar; keep in sync with the frontend's core/theme/themes.ts. */
export const THEME_IDS = ['golden', 'espresso', 'berry', 'forest'] as const;
export type ThemeId = (typeof THEME_IDS)[number];

export class SetThemeDto {
  @ApiProperty({ enum: THEME_IDS, example: 'golden' })
  @IsIn(THEME_IDS, { message: `Theme must be one of ${THEME_IDS.join(', ')}` })
  theme!: ThemeId;
}
