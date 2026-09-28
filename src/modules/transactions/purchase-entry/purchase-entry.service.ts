import { BadRequestException, Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { FileStorageService, UploadedFileInfo } from '../../uploads/file-storage.service';
import { PeListQueryDto, PePaymentDto, PeSaveDto } from './dto/purchase-entry.dto';
import { PurchaseEntryItem, PurchaseEntryRepository, PurchaseEntryRow, PurchasePayment } from './purchase-entry.repository';

/** Purchase entry as the API exposes it (frontend `PurchaseEntry` model). */
export type PurchaseEntry = Omit<PurchaseEntryRow, 'invoiceFileUrl' | 'invoiceFileName' | 'isEditable'> & {
  invoiceCopy: UploadedFileInfo | null;
  isEditable: boolean;
  items: PurchaseEntryItem[];
  payments: PurchasePayment[];
};

@Injectable()
export class PurchaseEntryService {
  constructor(
    private readonly repo: PurchaseEntryRepository,
    private readonly files: FileStorageService,
  ) {}

  private view(row: PurchaseEntryRow, items: PurchaseEntryItem[] = [], payments: PurchasePayment[] = []): PurchaseEntry {
    const { invoiceFileUrl, invoiceFileName, isEditable, ...rest } = row;
    return { ...rest, isEditable: isEditable === 1, invoiceCopy: this.files.fileInfo(invoiceFileUrl, invoiceFileName), items, payments };
  }

  async list(q: PeListQueryDto): Promise<ApiResult<PurchaseEntry[]>> {
    const r = await this.repo.list(q);
    return paged(r.data.map((row) => this.view(row)), r.total, { totals: r.totals });
  }

  async get(id: number): Promise<PurchaseEntry> {
    const r = await this.repo.get(id);
    return this.view(r.header, r.items, r.payments);
  }

  async save(id: number, dto: PeSaveDto, userId: number): Promise<ApiResult<PurchaseEntry>> {
    const file = await this.files.resolveFile(dto.invoiceCopy, 'invoice', 'invoiceCopy');
    const res = await this.repo.save(id, dto, file, userId);
    return ok(await this.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  async addPayment(id: number, dto: PePaymentDto, userId: number): Promise<ApiResult<PurchaseEntry>> {
    const date = dto.date ?? dto.paymentDate;
    if (!date) throw new BadRequestException({ message: 'Payment date is required', field: 'date' });
    const res = await this.repo.addPayment(id, dto, date, userId);
    return ok(await this.get(id), res.message);
  }
}
