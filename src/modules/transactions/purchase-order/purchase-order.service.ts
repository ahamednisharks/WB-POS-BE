import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { PoListQueryDto, PoSaveDto } from './dto/purchase-order.dto';
import { OpenPo, PendingPoItem, PurchaseOrder, PurchaseOrderRepository } from './purchase-order.repository';

@Injectable()
export class PurchaseOrderService {
  constructor(private readonly repo: PurchaseOrderRepository) {}

  async list(q: PoListQueryDto): Promise<ApiResult<PurchaseOrder[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<PurchaseOrder> {
    return this.repo.get(id);
  }

  async save(id: number, dto: PoSaveDto, userId: number): Promise<ApiResult<PurchaseOrder>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  async cancel(id: number, reason: string, userId: number): Promise<ApiResult<PurchaseOrder>> {
    const res = await this.repo.cancel(id, reason.trim(), userId);
    return ok(await this.repo.get(id), res.message);
  }

  openBySupplier(supplierId: number): Promise<OpenPo[]> {
    return this.repo.openBySupplier(supplierId);
  }

  pendingItems(id: number): Promise<PendingPoItem[]> {
    return this.repo.pendingItems(id);
  }
}
