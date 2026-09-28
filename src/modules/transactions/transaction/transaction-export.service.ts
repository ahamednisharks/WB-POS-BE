import { Injectable } from '@nestjs/common';
import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import { formatInr } from '../../../common/utils/money.util';
import { ExportRow, TransactionSummary } from './transaction.repository';

export interface ExportMeta {
  shopName: string;
  from: string | null;
  to: string | null;
}

const TYPE_LABEL: Record<string, string> = { PAYMENT: 'Payment', REFUND: 'Refund', CASH_OUT: 'Cash out' };

/** Turns SP rows into files. No data access here - rows come from sp_transaction_export. */
@Injectable()
export class TransactionExportService {
  private period(meta: ExportMeta): string {
    if (!meta.from && !meta.to) return 'All dates';
    return `${meta.from ?? '...'} to ${meta.to ?? '...'}`;
  }

  private when(iso: string): string {
    return iso.replace('T', ' ').slice(0, 16);
  }

  async toExcel(rows: ExportRow[], summary: TransactionSummary, meta: ExportMeta): Promise<Buffer> {
    const wb = new ExcelJS.Workbook();
    wb.creator = 'WB-POS';
    const ws = wb.addWorksheet('Transactions', { views: [{ state: 'frozen', ySplit: 3 }] });

    ws.addRow([`${meta.shopName} - Transactions`]).font = { bold: true, size: 14 };
    ws.addRow([`Period: ${this.period(meta)}`]);
    const header = ws.addRow(['Txn No', 'Date & time', 'Type', 'Mode', 'Amount', 'Bill No', 'Reference', 'Note', 'By']);
    header.font = { bold: true };
    header.eachCell((c) => {
      c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF3E7D9' } };
    });

    for (const r of rows) {
      ws.addRow([r.txnNo, this.when(r.txnDate), TYPE_LABEL[r.type] ?? r.type, r.mode, r.amount, r.billNo ?? '', r.reference ?? '', r.note ?? '', r.cashierName]);
    }

    ws.addRow([]);
    const lines: [string, number][] = [
      ['Total received', summary.totalReceived],
      ['Cash', summary.cash],
      ['UPI', summary.upi],
      ['Card', summary.card],
      ['Refunds', summary.refunds],
      ['Cash paid out', summary.cashOuts],
      ['Net', summary.net],
    ];
    for (const [label, value] of lines) {
      const row = ws.addRow(['', '', '', label, value]);
      row.getCell(4).font = { bold: true };
    }

    ws.getColumn(5).numFmt = '#,##,##0.00';
    [16, 18, 10, 8, 14, 16, 16, 40, 20].forEach((w, i) => (ws.getColumn(i + 1).width = w));
    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  toPdf(rows: ExportRow[], summary: TransactionSummary, meta: ExportMeta): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 36 });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      doc.fontSize(16).font('Helvetica-Bold').text(`${meta.shopName} - Transactions`);
      doc.fontSize(10).font('Helvetica').text(`Period: ${this.period(meta)}`).moveDown();

      const cols = [
        { title: 'Txn No', w: 90 },
        { title: 'Date & time', w: 95 },
        { title: 'Type', w: 60 },
        { title: 'Mode', w: 50 },
        { title: 'Amount (Rs)', w: 75, right: true },
        { title: 'Bill No', w: 90 },
        { title: 'Note', w: 200 },
        { title: 'By', w: 90 },
      ];
      const left = doc.page.margins.left;
      const drawRow = (values: string[], bold = false): void => {
        if (doc.y > doc.page.height - doc.page.margins.bottom - 20) doc.addPage();
        const y = doc.y;
        let x = left;
        doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(8.5);
        cols.forEach((c, i) => {
          doc.text(values[i] ?? '', x, y, { width: c.w - 6, align: c.right ? 'right' : 'left', ellipsis: true, lineBreak: false });
          x += c.w;
        });
        doc.y = y + 14;
      };

      drawRow(cols.map((c) => c.title), true);
      for (const r of rows) {
        drawRow([r.txnNo, this.when(r.txnDate), TYPE_LABEL[r.type] ?? r.type, r.mode, formatInr(r.amount), r.billNo ?? '', r.note ?? '', r.cashierName]);
      }

      doc.moveDown();
      doc.x = left;
      doc.font('Helvetica-Bold').fontSize(10).text('Summary');
      doc.font('Helvetica').fontSize(9);
      const summaryLines: [string, number][] = [
        ['Total received', summary.totalReceived],
        ['Cash', summary.cash],
        ['UPI', summary.upi],
        ['Card', summary.card],
        ['Refunds', summary.refunds],
        ['Cash paid out', summary.cashOuts],
        ['Net', summary.net],
      ];
      for (const [label, value] of summaryLines) doc.text(`${label}: Rs ${formatInr(value)}`);
      doc.end();
    });
  }
}
