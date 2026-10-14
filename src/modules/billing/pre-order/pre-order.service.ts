import { BadRequestException, Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, ok, paged } from '../../../common/utils/api-result';
import { FileStorageService } from '../../uploads/file-storage.service';
import { BillPaymentDto } from '../bill/dto/bill.dto';
import { DATETIME_RE, PreOrderCancelDto, PreOrderListQueryDto, PreOrderSaveDto } from './dto/pre-order.dto';
import { PaymentParam, PreOrderRepository } from './pre-order.repository';
import { PreOrder, PreOrderListRow, PreOrderNextNo } from './pre-order.types';

const IST_OFFSET_MS = 330 * 60 * 1000;

/** API date-time -> IST wall clock 'YYYY-MM-DD HH:mm:ss' for MySQL. Values without an offset are taken as IST. */
export function toIstDateTime(value: string): string {
  const m = DATETIME_RE.exec(value.trim());
  if (!m) throw new BadRequestException({ message: 'Delivery date & time is invalid', field: 'deliveryAt' });
  const [, date, hhmm, ss, offset] = m;
  if (!offset) return `${date} ${hhmm}:${ss ?? '00'}`;
  const zone = offset === 'Z' ? 'Z' : offset.replace(/^([+-]\d{2}):?(\d{2})$/, '$1:$2');
  const t = Date.parse(`${date}T${hhmm}:${ss ?? '00'}${zone}`);
  if (Number.isNaN(t)) throw new BadRequestException({ message: 'Delivery date & time is invalid', field: 'deliveryAt' });
  const ist = new Date(t + IST_OFFSET_MS).toISOString();
  return `${ist.slice(0, 10)} ${ist.slice(11, 19)}`;
}

function toPayments(payments: BillPaymentDto[] | undefined): PaymentParam[] {
  return (payments ?? [])
    .filter((p) => p.amount > 0)
    .map((p) => ({
      mode: p.mode,
      amount: p.amount,
      referenceNo: p.referenceNo ?? p.reference ?? null,
      cashReceived: p.cashReceived ?? null,
    }));
}

function money(value: number): string {
  return Number(value).toFixed(2);
}

@Injectable()
export class PreOrderService {
  constructor(
    private readonly repo: PreOrderRepository,
    private readonly files: FileStorageService,
  ) {}

  /** Design photos are stored as /uploads paths; clients get absolute links. */
  private view(order: PreOrder): PreOrder {
    return { ...order, lines: order.lines.map((l) => ({ ...l, designUrl: this.files.publicLink(l.designUrl) })) };
  }

  async list(q: PreOrderListQueryDto): Promise<ApiResult<PreOrderListRow[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  async get(id: number): Promise<PreOrder> {
    return this.view(await this.repo.get(id));
  }

  nextNo(): Promise<PreOrderNextNo> {
    return this.repo.nextNo();
  }

  async save(id: number, dto: PreOrderSaveDto, user: AuthUser): Promise<ApiResult<PreOrder>> {
    // New photos arrive as data URLs and are written to disk; kept ones come back as our own links.
    const items = await Promise.all(
      dto.items.map(async (l) => ({
        itemId: l.itemId,
        qty: l.qty,
        rate: l.rate,
        notes: l.notes ?? null,
        designUrl: await this.files.resolveImage(l.design, 'items'),
      })),
    );
    const payments = toPayments(dto.payments);
    const order = this.view(
      await this.repo.save(
        id,
        {
          customerMobile: dto.customerMobile,
          customerName: dto.customerName,
          altMobile: dto.altMobile ?? null,
          deliveryAt: toIstDateTime(dto.deliveryAt),
          deliveryType: dto.deliveryType,
          deliveryAddress: dto.deliveryAddress ?? null,
          deliveryCharge: dto.deliveryCharge ?? 0,
          discountAmount: dto.discountAmount ?? 0,
          items,
          payments,
        },
        user,
      ),
    );
    const paid = payments.reduce((s, p) => s + p.amount, 0);
    const action = id > 0 ? 'updated' : 'booked';
    return ok(order, paid > 0 ? `Pre-order ${order.orderNo} ${action} with payment of ${money(paid)}` : `Pre-order ${order.orderNo} ${action}`);
  }

  async addPayments(id: number, dtoPayments: BillPaymentDto[], user: AuthUser): Promise<ApiResult<PreOrder>> {
    const payments = toPayments(dtoPayments);
    if (payments.length === 0) throw new BadRequestException({ message: 'Enter a payment amount greater than 0', field: 'payments' });
    const order = this.view(await this.repo.addPayments(id, payments, user));
    const paid = payments.reduce((s, p) => s + p.amount, 0);
    return ok(order, `Payment of ${money(paid)} recorded, balance due ${money(order.balance)}`);
  }

  async markReady(id: number, user: AuthUser): Promise<ApiResult<PreOrder>> {
    const order = this.view(await this.repo.markReady(id, user));
    return ok(order, `Pre-order ${order.orderNo} is ready`);
  }

  async deliver(id: number, dtoPayments: BillPaymentDto[] | undefined, user: AuthUser): Promise<ApiResult<PreOrder>> {
    const order = this.view(await this.repo.deliver(id, toPayments(dtoPayments), user));
    return ok(order, `Pre-order ${order.orderNo} delivered - bill ${order.billNo ?? ''} generated`);
  }

  async cancel(id: number, dto: PreOrderCancelDto, user: AuthUser): Promise<ApiResult<PreOrder>> {
    const order = this.view(
      await this.repo.cancel(
        id,
        {
          reason: dto.reason.trim(),
          refundAmount: dto.refundAmount,
          refundMode: dto.refundMode ?? null,
          referenceNo: dto.referenceNo ?? null,
        },
        user,
      ),
    );
    const refund = order.refundAmount ?? 0;
    return ok(order, refund > 0 ? `Pre-order ${order.orderNo} cancelled - refund of ${money(refund)} recorded` : `Pre-order ${order.orderNo} cancelled`);
  }
}
