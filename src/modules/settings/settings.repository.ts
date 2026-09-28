import { Injectable } from '@nestjs/common';
import { WriteResult } from '../../common/utils/api-result';
import { firstRow, Row } from '../../common/utils/to-camel';
import { DbService } from '../../database/db.service';
import { SettingsSaveDto } from './dto/settings-save.dto';

export interface ShopSettings {
  shopName: string;
  address: string | null;
  state: string;
  stateCode: string;
  gstin: string | null;
  phone: string | null;
  email: string | null;
  logo: string | null;
  upiId: string | null;
  receiptFooter: string | null;
  cashierMaxDiscountPct: number;
  allowNegativeStock: boolean;
  financialYearStartMonth: number;
  updatedAt: string | null;
}

@Injectable()
export class SettingsRepository {
  constructor(private readonly db: DbService) {}

  async get(): Promise<ShopSettings | null> {
    const [rows] = await this.db.call<Row>('sp_settings_get');
    return firstRow<ShopSettings>(rows);
  }

  async save(dto: SettingsSaveDto, logoUrl: string | null, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_settings_save', [
      dto.shopName,
      dto.address ?? null,
      dto.state,
      dto.gstin ?? null,
      dto.phone ?? null,
      dto.email ?? null,
      logoUrl,
      dto.upiId ?? null,
      dto.receiptFooter ?? null,
      dto.cashierMaxDiscountPct ?? null,
      dto.allowNegativeStock === undefined ? null : dto.allowNegativeStock ? 1 : 0,
      dto.financialYearStartMonth ?? null,
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }
}
