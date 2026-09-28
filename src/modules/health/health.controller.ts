import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { DbService } from '../../database/db.service';

interface HealthRow {
  ok: number;
  server_time: string;
  version: string;
}

@ApiTags('Health')
@Controller('health')
export class HealthController {
  constructor(private readonly db: DbService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'API + database status (public)' })
  async health(): Promise<{ status: string; db: string; dbTime: string; dbVersion: string }> {
    try {
      const row = await this.db.callOne<HealthRow>('sp_util_health');
      return { status: 'ok', db: row?.ok === 1 ? 'up' : 'down', dbTime: row?.server_time ?? '', dbVersion: row?.version ?? '' };
    } catch {
      throw new ServiceUnavailableException('Database is not reachable');
    }
  }
}
