import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';

export type MasterStatus = 'ACTIVE' | 'INACTIVE';

/** `status` field shared by master save DTOs. */
export class MasterStatusDto {
  @ApiPropertyOptional({ enum: ['ACTIVE', 'INACTIVE'], default: 'ACTIVE' })
  @IsOptional()
  @IsIn(['ACTIVE', 'INACTIVE'], { message: 'Status must be ACTIVE or INACTIVE' })
  status?: MasterStatus;
}

export function statusFlag(status: MasterStatus | undefined): number {
  return status === 'INACTIVE' ? 0 : 1;
}
