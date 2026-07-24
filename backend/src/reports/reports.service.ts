import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, SaleStatus } from '@prisma/client';
import * as ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';

/**
 * مدیریت گزارش‌های حسابداری و فروش. خروجی PDF فعلاً فونت پیش‌فرض pdfkit را استفاده می‌کند؛
 * برای نمایش کامل فارسی/راست-به-چپ باید یک فونت فارسی (مانند Vazirmatn.ttf) توسط دیپلویر registerFont شود.
 *
 * جمع مبالغ با Prisma.Decimal انجام می‌شود تا خطای گرد کردن اعشار در گزارش‌های مالی رخ ندهد.
 */
@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async profitAndLoss(startDate: Date, endDate: Date) {
    const sales = await this.prisma.sale.findMany({ where: { date: { gte: startDate, lte: endDate }, status: SaleStatus.ACTIVE } });
    const revenue = sales.reduce((sum, s) => sum.plus(s.totalAmount), new Prisma.Decimal(0));

    const purchases = await this.prisma.purchase.findMany({ where: { date: { gte: startDate, lte: endDate }, deletedAt: null } });
    const costOfGoods = purchases.reduce((sum, p) => sum.plus(p.totalAmount), new Prisma.Decimal(0));

    const expenses = await this.prisma.expense.findMany({ where: { date: { gte: startDate, lte: endDate }, deletedAt: null } });
    const operatingExpenses = expenses
      .filter((e) => !e.isPersonal)
      .reduce((sum, e) => sum.plus(e.amount), new Prisma.Decimal(0));
    const personalWithdrawals = expenses
      .filter((e) => e.isPersonal)
      .reduce((sum, e) => sum.plus(e.amount), new Prisma.Decimal(0));

    const payrolls = await this.prisma.payroll.findMany({ where: { periodStart: { gte: startDate }, periodEnd: { lte: endDate } } });
    const payrollCost = payrolls.reduce((sum, p) => sum.plus(p.netAmount), new Prisma.Decimal(0));

    const grossProfit = revenue.minus(costOfGoods);
    const netProfit = grossProfit.minus(operatingExpenses).minus(payrollCost);

    return {
      revenue,
      costOfGoods,
      grossProfit,
      operatingExpenses,
      payrollCost,
      personalWithdrawals,
      netProfit,
    };
  }

  async salesReport(startDate: Date, endDate: Date) {
    const items = await this.prisma.saleItem.findMany({
      where: { sale: { date: { gte: startDate, lte: endDate }, status: SaleStatus.ACTIVE } },
      include: { product: true },
    });

    const byProduct = new Map<string, { productName: string; quantity: number; total: Prisma.Decimal }>();
    for (const item of items) {
      const key = item.productId;
      const current = byProduct.get(key) ?? { productName: item.product.name, quantity: 0, total: new Prisma.Decimal(0) };
      current.quantity += item.quantity;
      current.total = current.total.plus(item.lineTotal);
      byProduct.set(key, current);
    }

    return Array.from(byProduct.values()).sort((a, b) => b.total.comparedTo(a.total));
  }

  async exportSalesCsv(startDate: Date, endDate: Date): Promise<string> {
    const rows = await this.salesReport(startDate, endDate);
    const header = 'محصول,تعداد فروش‌رفته,جمع فروش (ریال)';
    const lines = rows.map((r) => `${r.productName},${r.quantity},${r.total.toString()}`);
    return [header, ...lines].join('\n');
  }

  async exportSalesExcel(startDate: Date, endDate: Date): Promise<Buffer> {
    const rows = await this.salesReport(startDate, endDate);
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('گزارش فروش');
    sheet.views = [{ rightToLeft: true }];
    sheet.columns = [
      { header: 'محصول', key: 'productName', width: 30 },
      { header: 'تعداد فروش‌رفته', key: 'quantity', width: 20 },
      { header: 'جمع فروش (ریال)', key: 'total', width: 20 },
    ];
    sheet.addRows(rows.map((r) => ({ productName: r.productName, quantity: r.quantity, total: r.total.toNumber() })));
    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }

  async exportProfitLossPdf(startDate: Date, endDate: Date): Promise<Buffer> {
    const report = await this.profitAndLoss(startDate, endDate);
    return new Promise<Buffer>((resolve, reject) => {
      const doc = new PDFDocument({ margin: 40 });
      const chunks: Buffer[] = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      doc.fontSize(18).text('Profit & Loss Report', { align: 'center' });
      doc.moveDown();
      doc.fontSize(12);
      doc.text(`Period: ${startDate.toISOString().slice(0, 10)} - ${endDate.toISOString().slice(0, 10)}`);
      doc.moveDown();
      doc.text(`Revenue: ${report.revenue.toString()}`);
      doc.text(`Cost of Goods: ${report.costOfGoods.toString()}`);
      doc.text(`Gross Profit: ${report.grossProfit.toString()}`);
      doc.text(`Operating Expenses: ${report.operatingExpenses.toString()}`);
      doc.text(`Payroll Cost: ${report.payrollCost.toString()}`);
      doc.text(`Personal Withdrawals: ${report.personalWithdrawals.toString()}`);
      doc.moveDown();
      doc.fontSize(14).text(`Net Profit: ${report.netProfit.toString()}`);
      doc.end();
    });
  }
}
