import { Injectable } from '@nestjs/common';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { FileStorageService } from '../../uploads/file-storage.service';
import { Combo, ComboOption, ComboRepository } from './combo.repository';
import { ComboListQueryDto, ComboSaveDto } from './dto/combo.dto';

@Injectable()
export class ComboService {
  constructor(
    private readonly repo: ComboRepository,
    private readonly files: FileStorageService,
  ) {}

  private view(combo: Combo): Combo {
    return { ...combo, image: this.files.publicLink(combo.image) };
  }

  async list(q: ComboListQueryDto): Promise<ApiResult<Combo[]>> {
    const r = await this.repo.list(q);
    return paged(r.data.map((c) => this.view(c)), r.total);
  }

  async get(id: number): Promise<Combo> {
    return this.view(await this.repo.get(id));
  }

  async save(id: number, dto: ComboSaveDto, userId: number): Promise<ApiResult<Combo>> {
    const image = await this.files.resolveImage(dto.image);
    const res = await this.repo.save(id, dto, image, userId);
    return ok(await this.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  dropdown(): Promise<ComboOption[]> {
    return this.repo.dropdown();
  }
}
