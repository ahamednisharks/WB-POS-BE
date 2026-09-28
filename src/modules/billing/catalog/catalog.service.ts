import { Injectable } from '@nestjs/common';
import { FileStorageService } from '../../uploads/file-storage.service';
import { Catalog, CatalogRepository } from './catalog.repository';

@Injectable()
export class CatalogService {
  constructor(
    private readonly repo: CatalogRepository,
    private readonly files: FileStorageService,
  ) {}

  async catalog(): Promise<Catalog> {
    const c = await this.repo.catalog();
    return {
      categories: c.categories.map((x) => ({ ...x, image: this.files.publicLink(x.image) })),
      items: c.items.map((x) => ({ ...x, image: this.files.publicLink(x.image) })),
      combos: c.combos.map((x) => ({ ...x, image: this.files.publicLink(x.image) })),
    };
  }
}
