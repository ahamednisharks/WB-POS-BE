import { BadRequestException, Injectable } from '@nestjs/common';
import { mapException } from '../../../common/filters/all-exceptions.filter';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { BillHeader, BillPayment, BillSyncResult, Bill, Receipt } from './bill.types';
import { BillRepository, BillSaveParams, HeldBill } from './bill.repository';
import { BillLineDto, BillListQueryDto, BillSaveDto } from './dto/bill.dto';

@Injectable()
export class BillService {
  constructor(private readonly repo: BillRepository) {}

  /** Accepts both request shapes and produces the JSON the SP reads. Prices are never forwarded. */
  toParams(dto: BillSaveDto): BillSaveParams {
    const source: BillLineDto[] = dto.items?.length ? dto.items : (dto.lines ?? []);
    if (source.length === 0) throw new BadRequestException({ message: 'Add at least one item to the bill', field: 'items' });

    const items = source.map((l) => {
      const itemId = l.itemId ?? (l.kind !== 'COMBO' ? l.refId : undefined) ?? undefined;
      const comboId = l.comboId ?? (l.kind === 'COMBO' ? l.refId : undefined) ?? undefined;
      if (!!itemId === !!comboId) {
        throw new BadRequestException({ message: 'Each bill line needs exactly one of itemId or comboId', field: 'items' });
      }
      return itemId ? { itemId, qty: l.qty } : { comboId: comboId!, qty: l.qty };
    });

    let cashApplied = false;
    const payments = (dto.status === 'COMPLETED' ? (dto.payments ?? []) : [])
      .filter((p) => p.amount > 0)
      .map((p) => {
        let cashReceived = p.cashReceived ?? null;
        if (p.mode === 'CASH' && cashReceived === null && !cashApplied && dto.cashReceived != null) {
          cashReceived = dto.cashReceived;
          cashApplied = true;
        }
        return { mode: p.mode, amount: p.amount, referenceNo: p.referenceNo ?? p.reference ?? null, cashReceived };
      });

    return {
      clientRef: dto.clientRef ?? null,
      deviceId: dto.deviceId ?? null,
      status: dto.status,
      customerMobile: dto.customerMobile ?? null,
      customerName: dto.customerName ?? null,
      discountType: dto.discountType ?? 'AMOUNT',
      discountValue: dto.discountValue ?? 0,
      items,
      payments,
    };
  }

  private message(bill: Bill): string {
    return bill.status === 'HELD' ? `Bill ${bill.billNo} put on hold` : `Bill ${bill.billNo} saved`;
  }

  async save(dto: BillSaveDto, user: AuthUser): Promise<ApiResult<Bill>> {
    const bill = await this.repo.save(dto.heldBillId ?? 0, this.toParams(dto), user);
    return ok(bill, this.message(bill));
  }

  async completeHeld(id: number, dto: BillSaveDto, user: AuthUser): Promise<ApiResult<Bill>> {
    const bill = await this.repo.completeHeld(id, { ...this.toParams({ ...dto, status: 'COMPLETED' }) }, user);
    return ok(bill, this.message(bill));
  }

  /** Offline queue: each bill is saved on its own; one failure does not stop the rest. */
  async sync(bills: BillSaveDto[], user: AuthUser): Promise<ApiResult<BillSyncResult[]>> {
    const results: BillSyncResult[] = [];
    for (const dto of bills) {
      const clientRef = dto.clientRef ?? null;
      try {
        if (!clientRef) throw new BadRequestException('clientRef is required for offline sync');
        const bill = await this.repo.save(0, this.toParams(dto), user);
        results.push({ clientRef, id: bill.id, billNo: bill.billNo });
      } catch (e) {
        results.push({ clientRef, id: null, billNo: null, error: mapException(e).message });
      }
    }
    const failed = results.filter((r) => r.error).length;
    return ok(results, failed ? `${results.length - failed} synced, ${failed} failed` : `${results.length} bill(s) synced`);
  }

  get(id: number, user: AuthUser): Promise<Bill> {
    return this.repo.get(id, user);
  }

  async list(q: BillListQueryDto, user: AuthUser): Promise<ApiResult<(BillHeader & { payments: BillPayment[] })[]>> {
    const r = await this.repo.list(q, user);
    return paged(r.data, r.total);
  }

  heldList(user: AuthUser): Promise<HeldBill[]> {
    return this.repo.heldList(user);
  }

  async deleteHeld(id: number, user: AuthUser): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.deleteHeld(id, user);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  async cancel(id: number, reason: string, remarks: string | null, user: AuthUser): Promise<ApiResult<Bill>> {
    const res = await this.repo.cancel(id, reason.trim(), remarks, user);
    return ok(await this.repo.get(id, user), res.message);
  }

  async receipt(id: number, duplicate: boolean, user: AuthUser): Promise<Receipt> {
    const r = await this.repo.receipt(id, duplicate, user);
    return {
      shop: r.shop,
      bill: r.bill,
      isDuplicate: r.flag?.['isDuplicate'] === 1 || r.flag?.['isDuplicate'] === true,
      copyLabel: r.flag?.['copyLabel'] === 'DUPLICATE' ? 'DUPLICATE' : 'ORIGINAL',
    };
  }
}
