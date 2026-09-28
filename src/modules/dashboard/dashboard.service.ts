import { Injectable } from '@nestjs/common';
import { DashboardRepository, HourlySales, LowStockItem, RecentBill, TopItem } from './dashboard.repository';

/** Frontend `DashboardData` plus low-stock items. */
export interface DashboardData {
  from: string;
  to: string;
  totalSales: number;
  totalBills: number;
  averageBill: number;
  cancelledCount: number;
  cancelledAmount: number;
  paymentSplit: { cash: number; upi: number; card: number };
  salesByHour: HourlySales[];
  topItems: TopItem[];
  recentBills: RecentBill[];
  lowStock: LowStockItem[];
}

@Injectable()
export class DashboardService {
  constructor(private readonly repo: DashboardRepository) {}

  async summary(from?: string, to?: string): Promise<DashboardData> {
    const s = await this.repo.summary(from ?? null, to ?? null);
    const byMode = (mode: string): number => s.split.find((x) => x.mode === mode)?.amount ?? 0;
    return {
      from: s.cards.fromDate,
      to: s.cards.toDate,
      totalSales: s.cards.totalSales,
      totalBills: Number(s.cards.totalBills),
      averageBill: s.cards.avgBill,
      cancelledCount: Number(s.cards.cancelledCount),
      cancelledAmount: s.cards.cancelledAmount,
      paymentSplit: { cash: byMode('CASH'), upi: byMode('UPI'), card: byMode('CARD') },
      salesByHour: s.hours.map((h) => ({ hour: Number(h.hour), amount: h.amount, bills: Number(h.bills) })),
      topItems: s.topItems,
      recentBills: s.recentBills,
      lowStock: s.lowStock,
    };
  }
}
