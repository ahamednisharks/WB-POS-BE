export type BillStatus = 'HELD' | 'COMPLETED' | 'CANCELLED';

export interface BillLine {
  kind: 'ITEM' | 'COMBO';
  refId: string;
  code: string;
  name: string;
  unitCode: string;
  allowDecimal: boolean;
  qty: number;
  rate: number;
  gstPercent: number;
  priceIncludesGst: boolean;
  amount: number;
  discount: number;
  taxable: number;
  gstAmount: number;
  cgst: number;
  sgst: number;
  total: number;
}

export interface BillPayment {
  mode: 'CASH' | 'UPI' | 'CARD';
  amount: number;
  reference: string | null;
  cashReceived?: number | null;
  changeReturned?: number | null;
}

export interface BillHistoryEntry {
  status: BillStatus;
  at: string;
  by: string;
  note: string | null;
}

export interface BillHeader {
  id: string;
  billNo: string;
  billDate: string;
  cashierId: string;
  cashierName: string;
  customerMobile: string;
  customerName: string;
  itemCount: number;
  discountType: 'AMOUNT' | 'PERCENT';
  discountValue: number;
  subTotal: number;
  discountAmount: number;
  taxableAmount: number;
  cgst: number;
  sgst: number;
  totalGst: number;
  roundOff: number;
  grandTotal: number;
  paymentMode: 'CASH' | 'UPI' | 'CARD' | 'SPLIT' | null;
  cashReceived: number | null;
  changeReturned: number | null;
  status: BillStatus;
  cancelReason: string | null;
  createdAt: string;
  updatedAt: string;
}

/** Full bill (frontend `Bill` model). */
export interface Bill extends BillHeader {
  lines: BillLine[];
  payments: BillPayment[];
  history: BillHistoryEntry[];
}

export interface BillSyncResult {
  clientRef: string | null;
  id: string | null;
  billNo: string | null;
  error?: string;
}

export interface Receipt {
  shop: Record<string, unknown> | null;
  bill: Bill;
  isDuplicate: boolean;
  copyLabel: 'ORIGINAL' | 'DUPLICATE';
}
