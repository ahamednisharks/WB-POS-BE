import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { SupplierLedgerQueryDto, SupplierListQueryDto, SupplierSaveDto } from './dto/supplier.dto';
import { Supplier, SupplierLedger, SupplierOption, SupplierRepository } from './supplier.repository';

@Injectable()
export class SupplierService {
  constructor(private readonly repo: SupplierRepository) {}

  async list(q: SupplierListQueryDto): Promise<ApiResult<Supplier[]>> {
    const r = await this.repo.list(q);
    return paged(r.data, r.total);
  }

  get(id: number): Promise<Supplier> {
    return this.repo.get(id);
  }

  async save(id: number, dto: SupplierSaveDto, userId: number): Promise<ApiResult<Supplier>> {
    const res = await this.repo.save(id, dto, userId);
    return ok(await this.repo.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  dropdown(): Promise<SupplierOption[]> {
    return this.repo.dropdown();
  }

  ledger(id: number, q: SupplierLedgerQueryDto): Promise<SupplierLedger> {
    return this.repo.ledger(id, q);
  }
}
