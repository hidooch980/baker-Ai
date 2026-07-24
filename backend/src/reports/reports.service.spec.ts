import { Prisma } from '@prisma/client';
import { ReportsService } from './reports.service';

/**
 * تست دقت اعشاری گزارش‌ها: جمع مبالغ باید با Prisma.Decimal انجام شود، نه number.
 * در جاوااسکریپت 0.1 + 0.2 === 0.30000000000000004 است؛ اگر این محاسبه با number انجام شود،
 * این تست‌ها شکست می‌خورند.
 */
describe('ReportsService decimal precision', () => {
  it('profitAndLoss جمع مبالغ را با Prisma.Decimal محاسبه می‌کند', async () => {
    const prisma = {
      sale: {
        findMany: jest.fn().mockResolvedValue([
          { totalAmount: new Prisma.Decimal('0.1') },
          { totalAmount: new Prisma.Decimal('0.2') },
        ]),
      },
      purchase: { findMany: jest.fn().mockResolvedValue([]) },
      expense: { findMany: jest.fn().mockResolvedValue([]) },
      payroll: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    const service = new ReportsService(prisma);
    const report = await service.profitAndLoss(new Date('2026-01-01'), new Date('2026-01-31'));

    expect(report.revenue).toBeInstanceOf(Prisma.Decimal);
    expect(report.revenue.toString()).toBe('0.3');
    expect(report.grossProfit.toString()).toBe('0.3');
    expect(report.netProfit.toString()).toBe('0.3');
  });

  it('salesReport جمع هر محصول را با Prisma.Decimal محاسبه می‌کند', async () => {
    const prisma = {
      saleItem: {
        findMany: jest.fn().mockResolvedValue([
          { productId: 'p-1', quantity: 1, lineTotal: new Prisma.Decimal('0.1'), product: { name: 'نان بربری' } },
          { productId: 'p-1', quantity: 1, lineTotal: new Prisma.Decimal('0.2'), product: { name: 'نان بربری' } },
        ]),
      },
    } as any;

    const service = new ReportsService(prisma);
    const rows = await service.salesReport(new Date('2026-01-01'), new Date('2026-01-31'));

    expect(rows).toHaveLength(1);
    expect(rows[0].total).toBeInstanceOf(Prisma.Decimal);
    expect(rows[0].total.toString()).toBe('0.3');
    expect(rows[0].quantity).toBe(2);
  });
});
