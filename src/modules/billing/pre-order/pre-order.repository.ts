import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { PagedData } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { DeliveryType, PreOrderListQueryDto } from './dto/pre-order.dto';
import { PreOrder, PreOrderHeader, PreOrderLine, PreOrderListRow, PreOrderNextNo, PreOrderPayment } from './pre-order.types';

export interface PaymentParam {
  mode: string;
  amount: number;
  referenceNo: string | null;
  cashReceived: number | null;
}

/** Normalised input for sp_preorder_save (built by the service). */
export interface PreOrderSaveParams {
  customerMobile: string;
  customerName: string;
  altMobile: string | null;
  /** IST wall clock, 'YYYY-MM-DD HH:mm:ss'. */
  deliveryAt: string;
  deliveryType: DeliveryType;
  deliveryAddress: string | null;
  deliveryCharge: number;
  discountAmount: number;
  items: { itemId: number; qty: number; rate: number; notes: string | null; designUrl: string | null }[];
  payments: PaymentParam[];
}

export interface PreOrderCancelParams {
  reason: string;
  refundAmount: number;
  refundMode: string | null;
  referenceNo: string | null;
}

/** Result sets header, lines, payments -> PreOrder. */
function toPreOrder(sets: Row[][]): PreOrder {
  const [header, lines, payments] = sets;
  return {
    ...firstRow<PreOrderHeader>(header)!,
    lines: mapRows<PreOrderLine>(lines),
    payments: mapRows<PreOrderPayment>(payments),
  };
}

@Injectable()
export class PreOrderRepository {
  constructor(private readonly db: DbService) {}

  async save(id: number, p: PreOrderSaveParams, user: AuthUser): Promise<PreOrder> {
    const sets = await this.db.call<Row>('sp_preorder_save', [
      id,
      p.customerMobile,
      p.customerName,
      p.altMobile,
      p.deliveryAt,
      p.deliveryType,
      p.deliveryAddress,
      p.deliveryCharge,
      p.discountAmount,
      JSON.stringify(p.items),
      JSON.stringify(p.payments),
      user.id,
      user.role,
    ]);
    return toPreOrder(sets);
  }

  async get(id: number): Promise<PreOrder> {
    return toPreOrder(await this.db.call<Row>('sp_preorder_get', [id]));
  }

  async nextNo(): Promise<PreOrderNextNo> {
    const [rows] = await this.db.call<Row>('sp_preorder_next_no');
    return firstRow<PreOrderNextNo>(rows)!;
  }

  async list(q: PreOrderListQueryDto): Promise<PagedData<PreOrderListRow>> {
    const { sortBy, sortDir } = sortOf(q, 'asc');
    const [rows, count] = await this.db.call<Row>('sp_preorder_list', [
      q.from ?? null,
      q.to ?? null,
      filterValue(q.status),
      searchOf(q),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<PreOrderListRow>(rows), total: totalOf(count) };
  }

  async addPayments(id: number, payments: PaymentParam[], user: AuthUser): Promise<PreOrder> {
    return toPreOrder(await this.db.call<Row>('sp_preorder_add_payment', [id, JSON.stringify(payments), user.id]));
  }

  async markReady(id: number, user: AuthUser): Promise<PreOrder> {
    return toPreOrder(await this.db.call<Row>('sp_preorder_mark_ready', [id, user.id]));
  }

  async deliver(id: number, payments: PaymentParam[], user: AuthUser): Promise<PreOrder> {
    return toPreOrder(await this.db.call<Row>('sp_preorder_deliver', [id, JSON.stringify(payments), user.id]));
  }

  async cancel(id: number, p: PreOrderCancelParams, user: AuthUser): Promise<PreOrder> {
    const sets = await this.db.call<Row>('sp_preorder_cancel', [
      id,
      p.reason,
      p.refundAmount,
      p.refundMode,
      p.referenceNo,
      user.id,
      user.role,
    ]);
    return toPreOrder(sets);
  }
}
