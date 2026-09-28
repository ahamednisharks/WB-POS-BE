import { Injectable } from '@nestjs/common';
import { MasterStatus, statusFlag } from '../../../common/dto/status.dto';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { activeFlag, filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { SupplierLedgerQueryDto, SupplierListQueryDto, SupplierSaveDto } from './dto/supplier.dto';

export interface Supplier {
  id: string;
  code: string;
  name: string;
  contactPerson: string;
  mobile: string;
  email: string;
  address: string;
  state: string;
  stateCode: string;
  gstin: string;
  openingBalance: number;
  paymentTermsDays: number;
  currentBalance: number;
  isInterState: boolean;
  status: MasterStatus;
  createdAt: string;
  updatedAt: string;
}

export interface SupplierOption {
  id: string;
  code: string;
  name: string;
  state: string;
  gstin: string;
  mobile: string;
  paymentTermsDays: number;
  currentBalance: number;
  isInterState: boolean;
}

export interface SupplierLedgerRow {
  entryDate: string;
  docType: 'PURCHASE' | 'PAYMENT';
  docNo: string;
  reference: string;
  peId: string;
  credit: number;
  debit: number;
  balance: number;
}

export interface SupplierLedger {
  supplier: Row | null;
  rows: SupplierLedgerRow[];
}

@Injectable()
export class SupplierRepository {
  constructor(private readonly db: DbService) {}

  async list(q: SupplierListQueryDto): Promise<PagedData<Supplier>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_supplier_list', [
      searchOf(q),
      activeFlag(q.status),
      filterValue(q.state),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<Supplier>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<Supplier> {
    const [rows] = await this.db.call<Row>('sp_supplier_get', [id]);
    return firstRow<Supplier>(rows)!;
  }

  async save(id: number, dto: SupplierSaveDto, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_supplier_save', [
      id,
      dto.name,
      dto.contactPerson ?? null,
      dto.mobile,
      dto.email ?? null,
      dto.address,
      dto.state,
      dto.gstin ?? null,
      dto.openingBalance ?? 0,
      dto.paymentTermsDays ?? 0,
      statusFlag(dto.status),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_supplier_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(): Promise<SupplierOption[]> {
    const [rows] = await this.db.call<Row>('sp_supplier_dropdown');
    return mapRows<SupplierOption>(rows);
  }

  async ledger(id: number, q: SupplierLedgerQueryDto): Promise<SupplierLedger> {
    const [header, rows] = await this.db.call<Row>('sp_supplier_ledger', [id, q.from ?? null, q.to ?? null]);
    return { supplier: firstRow(header), rows: mapRows<SupplierLedgerRow>(rows) };
  }
}
