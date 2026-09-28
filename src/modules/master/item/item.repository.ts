import { Injectable } from '@nestjs/common';
import { MasterStatus, statusFlag } from '../../../common/dto/status.dto';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { activeFlag, boolFlag, filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { ItemListQueryDto, ItemSaveDto, ItemType, StockAdjustDto, StockLedgerQueryDto } from './dto/item.dto';

export interface Item {
  id: string;
  code: string;
  name: string;
  type: ItemType;
  categoryId: string;
  categoryName: string;
  unitId: string;
  unitName: string;
  unitCode: string;
  allowDecimal: boolean;
  sellingPrice: number;
  purchasePrice: number;
  gstPercent: number;
  priceIncludesGst: boolean;
  hsnCode: string;
  barcode: string;
  currentStock: number;
  minStock: number;
  image: string | null;
  status: MasterStatus;
  createdAt: string;
  updatedAt: string;
}

export interface ItemOption {
  id: string;
  code: string;
  name: string;
  type: ItemType;
  unitCode: string;
  allowDecimal: boolean;
  sellingPrice: number;
  purchasePrice: number;
  gstPercent: number;
  priceIncludesGst: boolean;
  currentStock: number;
}

export interface StockLedgerRow {
  id: string;
  txnDate: string;
  type: string;
  refTable: string | null;
  refId: string | null;
  refNo: string | null;
  qtyIn: number;
  qtyOut: number;
  balanceAfter: number;
}

export interface StockLedger {
  item: Row | null;
  rows: StockLedgerRow[];
  total: number;
}

@Injectable()
export class ItemRepository {
  constructor(private readonly db: DbService) {}

  async list(q: ItemListQueryDto): Promise<PagedData<Item>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_item_list', [
      searchOf(q),
      activeFlag(q.status),
      q.categoryId ?? null,
      filterValue(q.type ?? q.itemType),
      filterValue(q.barcode),
      boolFlag(q.saleable),
      boolFlag(q.purchasable),
      boolFlag(q.lowStock),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<Item>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<Item> {
    const [rows] = await this.db.call<Row>('sp_item_get', [id]);
    return firstRow<Item>(rows)!;
  }

  async getByBarcode(code: string): Promise<Item> {
    const [rows] = await this.db.call<Row>('sp_item_get_by_barcode', [code]);
    return firstRow<Item>(rows)!;
  }

  async save(id: number, dto: ItemSaveDto, imageUrl: string | null, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_item_save', [
      id,
      dto.code ?? null,
      dto.name,
      dto.type,
      dto.categoryId,
      dto.unitId,
      dto.sellingPrice ?? 0,
      dto.gstPercent,
      dto.priceIncludesGst === false ? 0 : 1,
      dto.hsnCode ?? null,
      dto.barcode ?? null,
      dto.minStock ?? 0,
      imageUrl,
      statusFlag(dto.status),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_item_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(type: ItemType | null): Promise<ItemOption[]> {
    const [rows] = await this.db.call<Row>('sp_item_dropdown', [type]);
    return mapRows<ItemOption>(rows);
  }

  async stockAdjust(id: number, dto: StockAdjustDto, userId: number): Promise<WriteResult & { currentStock: number }> {
    const [rows] = await this.db.call<Row>('sp_item_stock_adjust', [id, dto.type, dto.qty, dto.remarks ?? null, userId]);
    return firstRow<WriteResult & { currentStock: number }>(rows)!;
  }

  async stockLedger(id: number, q: StockLedgerQueryDto): Promise<StockLedger> {
    const [item, rows, count] = await this.db.call<Row>('sp_item_stock_ledger', [id, q.from ?? null, q.to ?? null, q.page ?? 1, q.limit ?? 50]);
    return { item: firstRow(item), rows: mapRows<StockLedgerRow>(rows), total: totalOf(count) };
  }
}
