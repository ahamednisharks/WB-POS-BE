import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../common/types/auth-user';
import { ApiResult, ok } from '../../common/utils/api-result';
import { FileStorageService } from '../uploads/file-storage.service';
import { SettingsSaveDto } from './dto/settings-save.dto';
import { SettingsRepository, ShopSettings } from './settings.repository';

@Injectable()
export class SettingsService {
  constructor(
    private readonly repo: SettingsRepository,
    private readonly files: FileStorageService,
  ) {}

  async get(): Promise<ShopSettings | null> {
    const s = await this.repo.get();
    return s ? { ...s, logo: this.files.publicLink(s.logo) } : null;
  }

  async save(dto: SettingsSaveDto, user: AuthUser): Promise<ApiResult<ShopSettings | null>> {
    const logo = await this.files.resolveImage(dto.logo, 'logo');
    const res = await this.repo.save(dto, logo, user.id);
    return ok(await this.get(), res.message);
  }
}
