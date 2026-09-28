import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { Bill, BillHeader, BillHistoryEntry, BillLine, BillPayment } from './bill.types';
import { BillListQueryDto } from './dto/bill.dto';

/** Normalised input for sp_bill_save (built by the service from either request shape). */
export interface BillSaveParams {
  clientRef: string | null;
  deviceId: string | null;
  status: 'HELD' | 'COMPLETED';
  customerMobile: string | null;
  customerName: string | null;
  discountType: 'AMOUNT' | 'PERCENT';
  discountValue: number;
  items: { itemId?: number; comboId?: number; qty: number }[];
  payments: { mode: string; amount: number; referenceNo: string | null; cashReceived: number | null }[];
}

export interface HeldBill {
  id: string;
  billNo: string;
  billDate: string;
  cashierId: string;
  cashierName: string;
  customerMobile: string;
  customerName: string;
  itemCount: number;
  subTotal: number;
  discountAmount: number;
  grandTotal: number;
  status: 'HELD';
  linesSummary: { name: string; qty: number; total: number }[] | null;
}

/** Result sets header, lines, payments, history -> Bill. */
function toBill(sets: Row[][]): Bill {
  const [header, lines, payments, history] = sets;
  return {
    ...firstRow<BillHeader>(header)!,
    lines: mapRows<BillLine>(lines),
    payments: mapRows<BillPayment>(payments),
    history: mapRows<BillHistoryEntry>(history),
  };
}

@Injectable()
export class BillRepository {
  constructor(private readonly db: DbService) {}

  async save(id: number, p: BillSaveParams, user: AuthUser): Promise<Bill> {
    const sets = await this.db.call<Row>('sp_bill_save', [
      id,
      p.clientRef,
      p.deviceId,
      p.status,
      p.customerMobile,
      p.customerName,
      p.discountType,
      p.discountValue,
      JSON.stringify(p.items),
      JSON.stringify(p.payments),
      user.id,
      user.role,
    ]);
    return toBill(sets);
  }

  async completeHeld(id: number, p: BillSaveParams, user: AuthUser): Promise<Bill> {
    const sets = await this.db.call<Row>('sp_bill_complete_held', [
      id,
      p.clientRef,
      p.deviceId,
      p.customerMobile,
      p.customerName,
      p.discountType,
      p.discountValue,
      JSON.stringify(p.items),
      JSON.stringify(p.payments),
      user.id,
      user.role,
    ]);
    return toBill(sets);
  }

  async get(id: number, user: AuthUser): Promise<Bill> {
    return toBill(await this.db.call<Row>('sp_bill_get', [id, user.id, user.role]));
  }

  async list(q: BillListQueryDto, user: AuthUser): Promise<PagedData<BillHeader & { payments: BillPayment[] }>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_bill_list', [
      q.from ?? null,
      q.to ?? null,
      filterValue(q.status),
      q.cashierId ?? null,
      filterValue(q.paymentMode),
      searchOf(q),
      sortBy,
      sortDir,
      ...pageArgs(q),
      user.id,
      user.role,
    ]);
    const data = mapRows<BillHeader & { payments: BillPayment[] | null }>(rows).map((b) => ({ ...b, payments: b.payments ?? [] }));
    return { data, total: totalOf(count) };
  }

  async heldList(user: AuthUser): Promise<HeldBill[]> {
    const [rows] = await this.db.call<Row>('sp_bill_held_list', [user.id, user.role]);
    return mapRows<HeldBill>(rows);
  }

  async deleteHeld(id: number, user: AuthUser): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_bill_delete_held', [id, user.id, user.role]);
    return firstRow<DeleteResult>(rows)!;
  }

  async cancel(id: number, reason: string, remarks: string | null, user: AuthUser): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_bill_cancel', [id, reason, remarks, user.id, user.role]);
    return firstRow<WriteResult>(rows)!;
  }

  async receipt(id: number, duplicate: boolean, user: AuthUser): Promise<{ shop: Row | null; bill: Bill; flag: Row | null }> {
    const [shop, header, lines, payments, history, flag] = await this.db.call<Row>('sp_bill_receipt', [id, duplicate ? 1 : 0, user.id, user.role]);
    return { shop: firstRow(shop), bill: toBill([header, lines, payments, history]), flag: firstRow(flag) };
  }
}
