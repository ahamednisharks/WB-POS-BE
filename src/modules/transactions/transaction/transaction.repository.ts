import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/types/auth-user';
import { PagedData } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { TransactionListQueryDto } from './dto/transaction.dto';

export interface Transaction {
  id: string;
  txnNo: string;
  txnDate: string;
  type: 'PAYMENT' | 'REFUND' | 'CASH_OUT';
  mode: string;
  amount: number;
  reference: string | null;
  billId: string | null;
  billNo: string | null;
  purchaseEntryId: string | null;
  salaryPaymentId: string | null;
  note: string | null;
  cashierId: string;
  cashierName: string;
}

export interface TransactionSummary {
  totalReceived: number;
  cash: number;
  upi: number;
  card: number;
  refunds: number;
  cashRefunds: number;
  cashOuts: number;
  net: number;
}

export interface ExportRow {
  txnNo: string;
  txnDate: string;
  type: string;
  mode: string;
  amount: number;
  billNo: string | null;
  reference: string | null;
  note: string | null;
  cashierName: string;
}

const EMPTY_SUMMARY: TransactionSummary = { totalReceived: 0, cash: 0, upi: 0, card: 0, refunds: 0, cashRefunds: 0, cashOuts: 0, net: 0 };

@Injectable()
export class TransactionRepository {
  constructor(private readonly db: DbService) {}

  private filters(q: TransactionListQueryDto): unknown[] {
    return [q.from ?? null, q.to ?? null, filterValue(q.mode), filterValue(q.type), q.cashierId ?? null, searchOf(q)];
  }

  async list(q: TransactionListQueryDto, user: AuthUser): Promise<PagedData<Transaction> & { summary: TransactionSummary }> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count, summary] = await this.db.call<Row>('sp_transaction_list', [
      ...this.filters(q),
      sortBy,
      sortDir,
      ...pageArgs(q),
      user.id,
      user.role,
    ]);
    return { data: mapRows<Transaction>(rows), total: totalOf(count), summary: firstRow<TransactionSummary>(summary) ?? EMPTY_SUMMARY };
  }

  async export(q: TransactionListQueryDto, user: AuthUser): Promise<{ rows: ExportRow[]; summary: TransactionSummary }> {
    const [rows, summary] = await this.db.call<Row>('sp_transaction_export', [...this.filters(q), user.id, user.role]);
    return { rows: mapRows<ExportRow>(rows), summary: firstRow<TransactionSummary>(summary) ?? EMPTY_SUMMARY };
  }
}
