import { Injectable } from '@nestjs/common';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { PoListQueryDto, PoSaveDto } from './dto/purchase-order.dto';

export type PoStatus = 'DRAFT' | 'SENT' | 'PARTIAL' | 'RECEIVED' | 'CANCELLED';

export interface PurchaseOrderItem {
  poItemId: string;
  itemId: string;
  itemName: string;
  unitCode: string;
  qty: number;
  receivedQty: number;
  pendingQty?: number;
  rate: number;
  gstPercent: number;
  amount: number;
  gstAmount: number;
}

export interface PurchaseOrder {
  id: string;
  poNo: string;
  poDate: string;
  supplierId: string;
  supplierName: string;
  supplierGstin: string;
  supplierState: string;
  supplierMobile: string;
  isInterState: boolean;
  expectedDate: string | null;
  notes: string;
  items: PurchaseOrderItem[];
  subTotal: number;
  cgst: number;
  sgst: number;
  igst: number;
  totalGst: number;
  otherCharges: number;
  roundOff: number;
  grandTotal: number;
  status: PoStatus;
  cancelReason: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface OpenPo {
  id: string;
  poNo: string;
  poDate: string;
  expectedDate: string | null;
  status: PoStatus;
  grandTotal: number;
  pendingLines: number;
}

export interface PendingPoItem {
  poItemId: string;
  itemId: string;
  itemName: string;
  unitCode: string;
  orderedQty: number;
  receivedQty: number;
  pendingQty: number;
  rate: number;
  gstPercent: number;
}

@Injectable()
export class PurchaseOrderRepository {
  constructor(private readonly db: DbService) {}

  async list(q: PoListQueryDto): Promise<PagedData<PurchaseOrder>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_po_list', [
      searchOf(q),
      q.supplierId ?? null,
      filterValue(q.poStatus ?? q.status),
      q.from ?? null,
      q.to ?? null,
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    const data = mapRows<PurchaseOrder>(rows).map((po) => ({ ...po, items: po.items ?? [] }));
    return { data, total: totalOf(count) };
  }

  async get(id: number): Promise<PurchaseOrder> {
    const [header, items] = await this.db.call<Row>('sp_po_get', [id]);
    return { ...firstRow<Omit<PurchaseOrder, 'items'>>(header)!, items: mapRows<PurchaseOrderItem>(items) };
  }

  async save(id: number, dto: PoSaveDto, userId: number): Promise<WriteResult> {
    const items = dto.items.map((i) => ({ itemId: i.itemId, qty: i.qty, rate: i.rate, gstPercent: i.gstPercent ?? null }));
    const [rows] = await this.db.call<Row>('sp_po_save', [
      id,
      dto.poDate,
      dto.supplierId,
      dto.expectedDate ?? null,
      dto.notes ?? null,
      dto.otherCharges ?? 0,
      dto.status === 'SENT' || dto.status === 'SEND' ? 'SEND' : 'DRAFT',
      JSON.stringify(items),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_po_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async cancel(id: number, reason: string, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_po_cancel', [id, reason, userId]);
    return firstRow<WriteResult>(rows)!;
  }

  async openBySupplier(supplierId: number): Promise<OpenPo[]> {
    const [rows] = await this.db.call<Row>('sp_po_open_by_supplier', [supplierId]);
    return mapRows<OpenPo>(rows);
  }

  async pendingItems(id: number): Promise<PendingPoItem[]> {
    const [rows] = await this.db.call<Row>('sp_po_pending_items', [id]);
    return mapRows<PendingPoItem>(rows);
  }
}
