import { Injectable } from '@nestjs/common';
import { ListQueryDto } from '../../../common/dto/list-query.dto';
import { MasterStatus, statusFlag } from '../../../common/dto/status.dto';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { activeFlag, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { CategorySaveDto } from './dto/category.dto';

export interface Category {
  id: string;
  name: string;
  image: string | null;
  displayOrder: number;
  status: MasterStatus;
  itemCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface CategoryOption {
  id: string;
  name: string;
  image: string | null;
  displayOrder: number;
}

@Injectable()
export class CategoryRepository {
  constructor(private readonly db: DbService) {}

  async list(q: ListQueryDto): Promise<PagedData<Category>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_category_list', [
      searchOf(q),
      activeFlag(q.status),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<Category>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<Category> {
    const [rows] = await this.db.call<Row>('sp_category_get', [id]);
    return firstRow<Category>(rows)!;
  }

  async save(id: number, dto: CategorySaveDto, imageUrl: string | null, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_category_save', [
      id,
      dto.name,
      imageUrl,
      dto.displayOrder ?? 0,
      statusFlag(dto.status),
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_category_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(): Promise<CategoryOption[]> {
    const [rows] = await this.db.call<Row>('sp_category_dropdown');
    return mapRows<CategoryOption>(rows);
  }
}
