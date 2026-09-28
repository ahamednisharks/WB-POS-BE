import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags, ApiTooManyRequestsResponse } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AuthUser } from '../../common/types/auth-user';
import { ApiResult, ok } from '../../common/utils/api-result';
import { UserProfile } from './auth.repository';
import { AuthService, LoginResponse } from './auth.service';
import { ChangePasswordDto, LoginDto } from './dto/login.dto';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(200)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Log in (public). 5 wrong passwords lock the account for 15 minutes.' })
  @ApiOkResponse({
    schema: {
      example: {
        success: true,
        message: 'Login successful',
        data: { token: 'eyJhbGciOi...', expiresIn: '8h', user: { id: '1', name: 'Administrator', role: 'ADMIN', username: 'admin', employeeId: null } },
      },
    },
  })
  @ApiTooManyRequestsResponse({ description: 'More than 10 login attempts per minute from this IP' })
  async login(@Body() dto: LoginDto): Promise<ApiResult<LoginResponse>> {
    return ok(await this.auth.login(dto), 'Login successful');
  }

  @Get('me')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Profile of the logged-in user' })
  async me(@CurrentUser() user: AuthUser): Promise<UserProfile | null> {
    return this.auth.me(user.id);
  }

  @Post('change-password')
  @HttpCode(200)
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Change own password' })
  async changePassword(@CurrentUser() user: AuthUser, @Body() dto: ChangePasswordDto): Promise<ApiResult<{ message: string }>> {
    const res = await this.auth.changePassword(user, dto);
    return ok({ message: res.message }, res.message);
  }
}
