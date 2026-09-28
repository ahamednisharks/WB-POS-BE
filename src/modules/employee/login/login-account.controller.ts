import { Body, Controller, Delete, Get, HttpCode, Param, ParseIntPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { BlockDto, LoginCreateDto, LoginListQueryDto, LoginUpdateDto, ResetPasswordDto } from './dto/login-account.dto';
import { EligibleEmployee, LoginAccount } from './login-account.repository';
import { LoginAccountService } from './login-account.service';

@ApiTags('Employee - Logins')
@Controller('logins')
@Roles('ADMIN')
export class LoginAccountController {
  constructor(private readonly service: LoginAccountService) {}

  @Get()
  @ApiOperation({ summary: 'List logins (sp_login_list). Filters: status ACTIVE|BLOCKED, role, employeeId' })
  list(@Query() q: LoginListQueryDto): Promise<ApiResult<LoginAccount[]>> {
    return this.service.list(q);
  }

  @Get('eligible-employees')
  @ApiOperation({ summary: 'Active employees that can be given a login (sp_login_eligible_employees)' })
  eligible(): Promise<EligibleEmployee[]> {
    return this.service.eligibleEmployees();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get login (sp_login_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<LoginAccount> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create login; password hashed with bcrypt (sp_login_save)' })
  create(@Body() dto: LoginCreateDto, @CurrentUser() user: AuthUser): Promise<ApiResult<LoginAccount>> {
    return this.service.create(dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update username / role / status (sp_login_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: LoginUpdateDto, @CurrentUser() user: AuthUser): Promise<ApiResult<LoginAccount>> {
    return this.service.update(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete login, or block it when it has billing history (sp_login_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }

  @Post(':id/reset-password')
  @HttpCode(200)
  @ApiOperation({ summary: 'Set a new password and clear lockout (sp_login_reset_password)' })
  resetPassword(@Param('id', ParseIntPipe) id: number, @Body() dto: ResetPasswordDto, @CurrentUser() user: AuthUser): Promise<ApiResult<{ message: string }>> {
    return this.service.resetPassword(id, dto.password, user.id);
  }

  @Patch(':id/block')
  @ApiOperation({ summary: 'Block / unblock a login (sp_login_block)' })
  block(@Param('id', ParseIntPipe) id: number, @Body() dto: BlockDto, @CurrentUser() user: AuthUser): Promise<ApiResult<LoginAccount>> {
    return this.service.block(id, dto.blocked, user.id);
  }
}
