import { Injectable } from '@nestjs/common';
import { mapRows, Row } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';

export interface CatalogCategory {
  id: string;
  name: string;
  image: string | null;
  displayOrder: number;
}

export interface CatalogItem {
  id: string;
  code: string;
  name: string;
  type: 'SALE' | 'BOTH';
  categoryId: string;
  unitId: string;
  unitCode: string;
  allowDecimal: boolean;
  sellingPrice: number;
  gstPercent: number;
  priceIncludesGst: boolean;
  barcode: string;
  currentStock: number;
  image: string | null;
}

export interface CatalogComboItem {
  comboId: string;
  itemId: string;
  itemName: string;
  qty: number;
  price: number;
}

export interface CatalogCombo {
  id: string;
  name: string;
  comboPrice: number;
  actualPrice: number;
  savings: number;
  gstPercent: number;
  validFrom: string | null;
  validTo: string | null;
  image: string | null;
  items: CatalogComboItem[];
}

export interface Catalog {
  categories: CatalogCategory[];
  items: CatalogItem[];
  combos: CatalogCombo[];
}

@Injectable()
export class CatalogRepository {
  constructor(private readonly db: DbService) {}

  async catalog(): Promise<Catalog> {
    const [categories, items, combos, components] = await this.db.call<Row>('sp_billing_catalog');
    const parts = mapRows<CatalogComboItem>(components);
    return {
      categories: mapRows<CatalogCategory>(categories),
      items: mapRows<CatalogItem>(items),
      combos: mapRows<Omit<CatalogCombo, 'items'>>(combos).map((c) => ({ ...c, items: parts.filter((p) => p.comboId === c.id) })),
    };
  }
}
