import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SaleStatus } from '@prisma/client';
import * as ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';

/**
 * مدیریت گزارش‌های حسابداری و فروش. خروجی PDF فعلاً فونت پیش‌فرض pdfkit را استفاده می‌کند؛
 * برای نمایش کامل فارسی/RAST-TO-LEFT باید یک فونت فارسی (مانند Vazirmatn.ttf) توسط دیپلویر registerFont شود.
 */
@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async profitAndLoss(startDate: Date, endDate: Date) {
    const sales = await this.prisma.sale.findMany({ where: { date: { gte: startDate, lte: endDate }, status: SaleStatus.ACTIVE } });
    const revenue = sales.reduce((sum, s) => sum + Number(s.totalAmount), 0);

    const purchases = await this.prisma.purchase.findMany({ where: { date: { gte: startDate, lte: endDate }, deletedAt: null } });
    const costOfGoods = purchases.reduce((sum, p) => sum + Number(p.totalAmount), 0);

    const expenses = await this.prisma.expense.findMany({ where: { date: { gte: startDate, lte: endDate }, deletedAt: null } });
    const operatingExpenses = expenses.filter((e) => !e.isPersonal).reduce((sum, e) => sum + Number(e.amount), 0);
    const personalWithdrawals = expenses.filter((e) => e.isPersonal).reduce((sum, e) => sum + Number(e.amount), 0);

    const payrolls = await this.prisma.payroll.findMany({ where: { periodStart: { gte: startDate }, periodEnd: { lte: endDate } } });
    const payrollCost = payrolls.reduce((sum, p) => sum + Number(p.netAmount), 0);

    const grossProfit = revenue - costOfGoods;
    const netProfit = grossProfit - operatingExpenses - payrollCost;

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

    const byProduct = new Map<string, { productName: string; quantity: number; total: number }>();
    for (const item of items) {
      const key = item.productId;
      const current = byProduct.get(key) ?? { productName: item.product.name, quantity: 0, total: 0 };
      current.quantity += item.quantity;
      current.total += Number(item.lineTotal);
      byProduct.set(key, current);
    }

    return Array.from(byProduct.values()).sort((a, b) => b.total - a.total);
  }

  async exportSalesCsv(startDate: Date, endDate: Date): Promise<string> {
    const rows = await this.salesReport(startDate, endDate);
    const header = 'محصول,تعداد فروش‌رفته,جمع فروش (تومان)';
    const lines = rows.map((r) => `${r.productName},${r.quantity},${r.total}`);
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
      { header: 'جمع فروش (تومان)', key: 'total', width: 20 },
    ];
    sheet.addRows(rows);
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
      doc.text(`Revenue: ${report.revenue}`);
      doc.text(`Cost of Goods: ${report.costOfGoods}`);
      doc.text(`Gross Profit: ${report.grossProfit}`);
      doc.text(`Operating Expenses: ${report.operatingExpenses}`);
      doc.text(`Payroll Cost: ${report.payrollCost}`);
      doc.text(`Personal Withdrawals: ${report.personalWithdrawals}`);
      doc.moveDown();
      doc.fontSize(14).text(`Net Profit: ${report.netProfit}`);
      doc.end();
    });
  }
}
