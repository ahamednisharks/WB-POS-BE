export type PreOrderStatus = 'BOOKED' | 'READY' | 'DELIVERED' | 'CANCELLED';

export interface PreOrderLine {
  itemId: string;
  itemCode: string;
  itemName: string;
  categoryName: string;
  unitCode: string;
  allowDecimal: boolean;
  qty: number;
  /** Actual Price: Item Master price when the item was booked. */
  masterRate: number;
  /** Item Price: agreed price for this order. */
  rate: number;
  rateDiff: number;
  gstPercent: number;
  priceIncludesGst: boolean;
  amount: number;
  discount: number;
  taxable: number;
  gstAmount: number;
  cgst: number;
  sgst: number;
  total: number;
  notes: string;
  designUrl: string | null;
}

export interface PreOrderPayment {
  id: string;
  paidAt: string;
  mode: 'CASH' | 'UPI' | 'CARD';
  amount: number;
  reference: string | null;
  txnNo: string | null;
  /** Collected with the bill when the order was delivered. */
  atDelivery: boolean;
  receivedByName: string;
}

export interface PreOrderHeader {
  id: string;
  orderNo: string;
  orderDate: string;
  customerMobile: string;
  customerName: string;
  altMobile: string;
  deliveryAt: string;
  deliveryType: 'PICKUP' | 'HOME';
  deliveryAddress: string;
  deliveryCharge: number;
  itemCount: number;
  subTotal: number;
  discountAmount: number;
  taxableAmount: number;
  cgst: number;
  sgst: number;
  totalGst: number;
  roundOff: number;
  grandTotal: number;
  paidAmount: number;
  balance: number;
  status: PreOrderStatus;
  billId: string | null;
  billNo: string | null;
  readyAt: string | null;
  deliveredAt: string | null;
  cancelReason: string | null;
  refundAmount: number | null;
  refundMode: 'CASH' | 'UPI' | 'CARD' | null;
  cancelledAt: string | null;
  bookedByName: string;
  createdAt: string;
  updatedAt: string;
}

export interface PreOrder extends PreOrderHeader {
  lines: PreOrderLine[];
  payments: PreOrderPayment[];
}

/** List row: header money + a one-line summary of the items. */
export type PreOrderListRow = Omit<
  PreOrderHeader,
  'taxableAmount' | 'cgst' | 'sgst' | 'totalGst' | 'roundOff' | 'readyAt' | 'deliveredAt' | 'cancelReason' | 'refundAmount' | 'refundMode' | 'cancelledAt'
> & { itemsSummary: string | null };
