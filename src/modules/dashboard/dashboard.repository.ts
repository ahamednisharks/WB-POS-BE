import { Injectable } from '@nestjs/common';
import { firstRow, mapRows, Row } from '../../common/utils/to-camel';
import { DbService } from '../../database/db.service';

export interface DashboardCards {
  fromDate: string;
  toDate: string;
  totalSales: number;
  totalBills: number;
  avgBill: number;
  cancelledCount: number;
  cancelledAmount: number;
}

export interface HourlySales {
  hour: number;
  amount: number;
  bills: number;
}

export interface TopItem {
  name: string;
  qty: number;
  amount: number;
}

export interface RecentBill {
  id: string;
  billNo: string;
  billDate: string;
  cashierName: string;
  grandTotal: number;
  paymentMode: string | null;
}

export interface LowStockItem {
  id: string;
  code: string;
  name: string;
  type: string;
  unitCode: string;
  currentStock: number;
  minStock: number;
}

export interface DashboardSets {
  cards: DashboardCards;
  split: { mode: 'CASH' | 'UPI' | 'CARD'; amount: number }[];
  hours: HourlySales[];
  topItems: TopItem[];
  recentBills: RecentBill[];
  lowStock: LowStockItem[];
}

@Injectable()
export class DashboardRepository {
  constructor(private readonly db: DbService) {}

  async summary(from: string | null, to: string | null): Promise<DashboardSets> {
    const [cards, split, hours, top, recent, low] = await this.db.call<Row>('sp_dashboard_summary', [from, to]);
    return {
      cards: firstRow<DashboardCards>(cards)!,
      split: mapRows(split),
      hours: mapRows<HourlySales>(hours),
      topItems: mapRows<TopItem>(top),
      recentBills: mapRows<RecentBill>(recent),
      lowStock: mapRows<LowStockItem>(low),
    };
  }
}
