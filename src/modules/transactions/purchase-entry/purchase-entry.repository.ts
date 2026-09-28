import { Injectable } from '@nestjs/common';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { StoredFile } from '../../uploads/file-storage.service';
import { PeListQueryDto, PePaymentDto, PeSaveDto } from './dto/purchase-entry.dto';

export type PurchasePaymentStatus = 'UNPAID' | 'PARTLY_PAID' | 'PAID';

export interface PurchaseEntryItem {
  itemId: string;
  itemName: string;
  unitCode: string;
  poItemId: string | null;
  orderedQty: number | null;
  receivedQty: number;
  rate: number;
  gstPercent: number;
  expiryDate: string | null;
  amount: number;
  gstAmount: number;
  cgst: number;
  sgst: number;
  igst: number;
}

export interface PurchasePayment {
  id: string;
  amount: number;
  mode: string;
  date: string;
  reference: string | null;
  createdAt: string;
}

/** Header as the SPs return it (file columns are turned into `invoiceCopy` by the service). */
export interface PurchaseEntryRow {
  id: string;
  peNo: string;
  peDate: string;
  supplierId: string;
  supplierName: string;
  supplierState: string;
  isInterState: boolean;
  poId: string | null;
  poNo: string | null;
  invoiceNo: string;
  invoiceDate: string;
  invoiceFileUrl: string | null;
  invoiceFileName: string | null;
  itemCount?: number;
  subTotal: number;
  cgst: number;
  sgst: number;
  igst: number;
  totalGst: number;
  discount: number;
  otherCharges: number;
  roundOff: number;
  grandTotal: number;
  paidAmount: number;
  balance: number;
  dueDate: string | null;
  paymentStatus: PurchasePaymentStatus;
  isEditable: number;
  createdAt: string;
  updatedAt: string;
}

export interface PeTotals {
  grandTotal: number;
  paidAmount: number;
  balance: number;
}

@Injectable()
export class PurchaseEntryRepository {
  constructor(private readonly db: DbService) {}

  async list(q: PeListQueryDto): Promise<PagedData<PurchaseEntryRow> & { totals: PeTotals }> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count, totals] = await this.db.call<Row>('sp_pe_list', [
      searchOf(q),
      q.supplierId ?? null,
      filterValue(q.paymentStatus),
      q.from ?? null,
      q.to ?? null,
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<PurchaseEntryRow>(rows), total: totalOf(count), totals: firstRow<PeTotals>(totals)! };
  }

  async get(id: number): Promise<{ header: PurchaseEntryRow; items: PurchaseEntryItem[]; payments: PurchasePayment[] }> {
    const [header, items, payments] = await this.db.call<Row>('sp_pe_get', [id]);
    return { header: firstRow<PurchaseEntryRow>(header)!, items: mapRows<PurchaseEntryItem>(items), payments: mapRows<PurchasePayment>(payments) };
  }

  async save(id: number, dto: PeSaveDto, file: StoredFile | null, userId: number): Promise<WriteResult> {
    const items = dto.items.map((i) => ({
      itemId: i.itemId,
      orderedQty: i.orderedQty ?? null,
      receivedQty: i.receivedQty,
      rate: i.rate,
      gstPercent: i.gstPercent ?? null,
      expiryDate: i.expiryDate ?? null,
    }));
    const [rows] = await this.db.call<Row>('sp_pe_save', [
      id,
      dto.peDate,
      dto.supplierId,
      dto.poId ?? null,
      dto.invoiceNo.trim(),
      dto.invoiceDate,
      file?.url ?? null,
      file?.name ?? null,
      dto.discount ?? 0,
      dto.otherCharges ?? 0,
      dto.paidNow ?? 0,
      dto.paymentMode ?? null,
      JSON.stringify(items),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_pe_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async addPayment(id: number, dto: PePaymentDto, date: string, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_pe_add_payment', [id, dto.amount, dto.mode, date, dto.referenceNo ?? null, userId]);
    return firstRow<WriteResult>(rows)!;
  }
}
