import { Body, Controller, Get, Put } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AuthUser } from '../../common/types/auth-user';
import { ApiResult } from '../../common/utils/api-result';
import { SettingsSaveDto } from './dto/settings-save.dto';
import { ShopSettings } from './settings.repository';
import { SettingsService } from './settings.service';

@ApiTags('Settings')
@Controller('settings')
export class SettingsController {
  constructor(private readonly service: SettingsService) {}

  @Get()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Shop profile and billing rules' })
  get(): Promise<ShopSettings | null> {
    return this.service.get();
  }

  @Put()
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Update shop profile' })
  save(@Body() dto: SettingsSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<ShopSettings | null>> {
    return this.service.save(dto, user);
  }
}
