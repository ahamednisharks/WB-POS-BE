import { Injectable } from '@nestjs/common';
import { MasterStatus, statusFlag } from '../../../common/dto/status.dto';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { activeFlag, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { ComboListQueryDto, ComboSaveDto } from './dto/combo.dto';

export interface ComboItem {
  itemId: string;
  itemName: string;
  qty: number;
  price: number;
  unitCode?: string;
  currentPrice?: number;
}

export interface Combo {
  id: string;
  name: string;
  items: ComboItem[];
  actualPrice: number;
  comboPrice: number;
  savings: number;
  gstPercent: number;
  validFrom: string | null;
  validTo: string | null;
  image: string | null;
  status: MasterStatus;
  createdAt: string;
  updatedAt: string;
}

export interface ComboOption {
  id: string;
  name: string;
  comboPrice: number;
  actualPrice: number;
  gstPercent: number;
}

@Injectable()
export class ComboRepository {
  constructor(private readonly db: DbService) {}

  async list(q: ComboListQueryDto): Promise<PagedData<Combo>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_combo_list', [
      searchOf(q),
      activeFlag(q.status),
      q.activeOn ?? null,
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    const data = mapRows<Combo>(rows).map((c) => ({ ...c, items: c.items ?? [] }));
    return { data, total: totalOf(count) };
  }

  async get(id: number): Promise<Combo> {
    const [header, items] = await this.db.call<Row>('sp_combo_get', [id]);
    const combo = firstRow<Omit<Combo, 'items'>>(header)!;
    return { ...combo, items: mapRows<ComboItem>(items) };
  }

  async save(id: number, dto: ComboSaveDto, imageUrl: string | null, userId: number): Promise<WriteResult> {
    const items = dto.items.map((i) => ({ itemId: i.itemId, qty: i.qty }));
    const [rows] = await this.db.call<Row>('sp_combo_save', [
      id,
      dto.name,
      dto.comboPrice,
      dto.gstPercent ?? null,
      dto.validFrom ?? null,
      dto.validTo ?? null,
      imageUrl,
      statusFlag(dto.status),
      JSON.stringify(items),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_combo_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(): Promise<ComboOption[]> {
    const [rows] = await this.db.call<Row>('sp_combo_dropdown');
    return mapRows<ComboOption>(rows);
  }
}
