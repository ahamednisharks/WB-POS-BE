import { Injectable } from '@nestjs/common';
import { ListQueryDto } from '../../../common/dto/list-query.dto';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { FileStorageService } from '../../uploads/file-storage.service';
import { Category, CategoryOption, CategoryRepository } from './category.repository';
import { CategorySaveDto } from './dto/category.dto';

@Injectable()
export class CategoryService {
  constructor(
    private readonly repo: CategoryRepository,
    private readonly files: FileStorageService,
  ) {}

  private view<T extends { image: string | null }>(row: T): T {
    return { ...row, image: this.files.publicLink(row.image) };
  }

  async list(q: ListQueryDto): Promise<ApiResult<Category[]>> {
    const r = await this.repo.list(q);
    return paged(r.data.map((c) => this.view(c)), r.total);
  }

  async get(id: number): Promise<Category> {
    return this.view(await this.repo.get(id));
  }

  async save(id: number, dto: CategorySaveDto, userId: number): Promise<ApiResult<Category>> {
    const image = await this.files.resolveImage(dto.image);
    const res = await this.repo.save(id, dto, image, userId);
    return ok(await this.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  async dropdown(): Promise<CategoryOption[]> {
    return (await this.repo.dropdown()).map((c) => this.view(c));
  }
}
