import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DailyClosingService } from './daily-closing.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';

describe('DailyClosingService', () => {
  let service: DailyClosingService;
  let prisma: any;
  let auditLogService: { record: jest.Mock };

  beforeEach(async () => {
    prisma = {
      dailyClosing: { findUnique: jest.fn(), upsert: jest.fn(), update: jest.fn() },
      sale: { findMany: jest.fn().mockResolvedValue([]) },
      expense: { findMany: jest.fn().mockResolvedValue([]) },
      purchase: { findMany: jest.fn().mockResolvedValue([]) },
      flourTransaction: { findMany: jest.fn().mockResolvedValue([]) },
      fuelTransaction: { findMany: jest.fn().mockResolvedValue([]) },
      productionItem: { findMany: jest.fn().mockResolvedValue([]) },
      cashBox: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    auditLogService = { record: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        DailyClosingService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = moduleRef.get(DailyClosingService);
  });

  it('بستن روزی که قبلاً قفل شده باید خطا بدهد', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue({ isLocked: true });

    await expect(service.closeDay(new Date('2026-01-01'), 'user-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.dailyClosing.upsert).not.toHaveBeenCalled();
  });

  it('بازکردن روز بدون ذکر دلیل باید خطا بدهد', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue({ id: 'dc-1', isLocked: true });

    await expect(service.reopen(new Date('2026-01-01'), '', 'user-1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('بازکردن روزی که وجود ندارد باید خطای یافت نشد بدهد', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue(null);

    await expect(service.reopen(new Date('2026-01-01'), 'دلیل تست', 'user-1')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('بازکردن روز معتبر باید isLocked را false کند و در لاگ حسابرسی ثبت شود', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue({ id: 'dc-1', isLocked: true });
    prisma.dailyClosing.update.mockResolvedValue({ id: 'dc-1', isLocked: false, reopenReason: 'دلیل تست' });

    const result = await service.reopen(new Date('2026-01-01'), 'دلیل تست', 'user-1');

    expect(result.isLocked).toBe(false);
    expect(auditLogService.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'DAY_REOPEN', reason: 'دلیل تست' }),
    );
  });

  /**
   * تست دقت اعشاری: جمع فروش‌های روز باید با Prisma.Decimal انجام شود، نه number.
   * در جاوااسکریپت 0.1 + 0.2 === 0.30000000000000004 است؛ اگر این محاسبه با number انجام شود،
   * این تست شکست می‌خورد.
   */
  it('preview باید جمع فروش روز را با Decimal محاسبه کند و از خطای گرد کردن اعشار جلوگیری کند', async () => {
    prisma.sale.findMany.mockResolvedValue([
      { totalAmount: new Prisma.Decimal('0.1'), payments: [] },
      { totalAmount: new Prisma.Decimal('0.2'), payments: [] },
    ]);

    const totals = await service.preview(new Date('2026-01-01'));

    expect(totals.totalSales).toBeInstanceOf(Prisma.Decimal);
    expect(totals.totalSales.toString()).toBe('0.3');
  });

  it('preview باید approxProfit را با تفریق Decimal (نه number) محاسبه کند', async () => {
    prisma.sale.findMany.mockResolvedValue([{ totalAmount: new Prisma.Decimal('1.3'), payments: [] }]);
    prisma.expense.findMany.mockResolvedValue([
      { amount: new Prisma.Decimal('0.1'), isPersonal: false },
      { amount: new Prisma.Decimal('0.2'), isPersonal: true },
    ]);

    const totals = await service.preview(new Date('2026-01-01'));

    expect(totals.totalExpenses.toString()).toBe('0.1');
    expect(totals.personalWithdrawals.toString()).toBe('0.2');
    expect(totals.approxProfit).toBeInstanceOf(Prisma.Decimal);
    expect(totals.approxProfit.toString()).toBe('1');
  });
});
