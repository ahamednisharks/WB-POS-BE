import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { FileStorageService } from '../../uploads/file-storage.service';
import { ItemListQueryDto, ItemSaveDto, ItemType, StockAdjustDto, StockLedgerQueryDto } from './dto/item.dto';
import { Item, ItemOption, ItemRepository, StockLedgerRow } from './item.repository';

@Injectable()
export class ItemService {
  constructor(
    private readonly repo: ItemRepository,
    private readonly files: FileStorageService,
  ) {}

  private view(item: Item): Item {
    return { ...item, image: this.files.publicLink(item.image) };
  }

  async list(q: ItemListQueryDto): Promise<ApiResult<Item[]>> {
    const r = await this.repo.list(q);
    return paged(r.data.map((i) => this.view(i)), r.total);
  }

  async get(id: number): Promise<Item> {
    return this.view(await this.repo.get(id));
  }

  async getByBarcode(code: string): Promise<Item> {
    return this.view(await this.repo.getByBarcode(code));
  }

  async save(id: number, dto: ItemSaveDto, userId: number): Promise<ApiResult<Item>> {
    const image = await this.files.resolveImage(dto.image);
    const res = await this.repo.save(id, dto, image, userId);
    return ok(await this.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  dropdown(type?: ItemType): Promise<ItemOption[]> {
    return this.repo.dropdown(type ?? null);
  }

  async stockAdjust(id: number, dto: StockAdjustDto, userId: number): Promise<ApiResult<Item>> {
    const res = await this.repo.stockAdjust(id, dto, userId);
    return ok(await this.get(id), res.message);
  }

  async stockLedger(id: number, q: StockLedgerQueryDto): Promise<ApiResult<StockLedgerRow[]>> {
    const r = await this.repo.stockLedger(id, q);
    return paged(r.rows, r.total, { item: r.item });
  }
}
