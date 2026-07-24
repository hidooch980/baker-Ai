import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, InventoryTxType, PaymentMethodType, Prisma, SaleStatus } from '@prisma/client';

/**
 * بستن روز (روتین ترازنامه): تمام داده‌های مالی/تولیدی روز را جمع می‌کند، قفل می‌شود و دیگر قابل ویرایش نیست
 * مگر با باز‌کردن (reopen) همراه با دلیل و ثبت در لاگ حسابرسی.
 *
 * جمع مبالغ با Prisma.Decimal انجام می‌شود تا خطای گرد کردن اعشار در ترازنامه‌ی روز رخ ندهد.
 */
@Injectable()
export class DailyClosingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  private dayRange(date: Date) {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);
    return { start, end };
  }

  async findAll() {
    return this.prisma.dailyClosing.findMany({ orderBy: { date: 'desc' }, take: 100 });
  }

  async findByDate(date: Date) {
    const { start } = this.dayRange(date);
    const closing = await this.prisma.dailyClosing.findUnique({ where: { date: start } });
    if (!closing) throw new NotFoundException('بستن روز برای این تاریخ یافت نشد.');
    return closing;
  }

  async preview(date: Date) {
    return this.computeTotals(date);
  }

  private async computeTotals(date: Date) {
    const { start, end } = this.dayRange(date);

    const sales = await this.prisma.sale.findMany({
      where: { date: { gte: start, lt: end }, status: SaleStatus.ACTIVE },
      include: { payments: { include: { paymentMethod: true } } },
    });
    const totalSales = sales.reduce((sum, s) => sum.plus(s.totalAmount), new Prisma.Decimal(0));

    let cashSales = new Prisma.Decimal(0);
    let cardSales = new Prisma.Decimal(0);
    let creditSales = new Prisma.Decimal(0);
    for (const sale of sales) {
      for (const payment of sale.payments) {
        const amount = new Prisma.Decimal(payment.amount);
        if (payment.paymentMethod.type === PaymentMethodType.CASH) cashSales = cashSales.plus(amount);
        else if (payment.paymentMethod.type === PaymentMethodType.CARD) cardSales = cardSales.plus(amount);
        else if (payment.paymentMethod.type === PaymentMethodType.CREDIT) creditSales = creditSales.plus(amount);
      }
    }

    const expenses = await this.prisma.expense.findMany({ where: { date: { gte: start, lt: end }, deletedAt: null } });
    const totalExpenses = expenses
      .filter((e) => !e.isPersonal)
      .reduce((sum, e) => sum.plus(e.amount), new Prisma.Decimal(0));
    const personalWithdrawals = expenses
      .filter((e) => e.isPersonal)
      .reduce((sum, e) => sum.plus(e.amount), new Prisma.Decimal(0));

    const purchases = await this.prisma.purchase.findMany({ where: { date: { gte: start, lt: end }, deletedAt: null } });
    const totalPurchases = purchases.reduce((sum, p) => sum.plus(p.totalAmount), new Prisma.Decimal(0));

    const flourTx = await this.prisma.flourTransaction.findMany({ where: { date: { gte: start, lt: end }, type: InventoryTxType.CONSUMPTION } });
    const flourConsumedKg = flourTx.reduce((sum, t) => sum + t.totalWeightKg, 0);

    const fuelTx = await this.prisma.fuelTransaction.findMany({ where: { date: { gte: start, lt: end }, type: InventoryTxType.CONSUMPTION } });
    const fuelConsumedLiters = fuelTx.reduce((sum, t) => sum + t.liters, 0);

    const productionItems = await this.prisma.productionItem.findMany({ where: { production: { date: { gte: start, lt: end } } } });
    const totalProduction = productionItems.reduce((sum, i) => sum + i.producedQty, 0);
    const wasteQty = productionItems.reduce((sum, i) => sum + i.wasteQty, 0);

    const cashBox = await this.prisma.cashBox.findUnique({ where: { date: start } });
    const cashBalance = cashBox ? new Prisma.Decimal(cashBox.calculatedBalance ?? cashBox.openingBalance) : new Prisma.Decimal(0);

    const approxProfit = totalSales.minus(totalExpenses).minus(totalPurchases).minus(personalWithdrawals);

    return {
      totalProduction,
      totalSales,
      cashSales,
      cardSales,
      creditSales,
      totalExpenses,
      personalWithdrawals,
      totalPurchases,
      flourConsumedKg,
      fuelConsumedLiters,
      wasteQty,
      cashBalance,
      approxProfit,
    };
  }

  async closeDay(date: Date, closedById?: string) {
    const { start } = this.dayRange(date);
    const existing = await this.prisma.dailyClosing.findUnique({ where: { date: start } });
    if (existing?.isLocked) throw new BadRequestException('این روز قبلاً بسته شده است.');

    const totals = await this.computeTotals(date);

    const closing = await this.prisma.dailyClosing.upsert({
      where: { date: start },
      create: { date: start, ...totals, isLocked: true, closedById, closedAt: new Date() },
      update: { ...totals, isLocked: true, closedById, closedAt: new Date() },
    });

    await this.auditLogService.record({ userId: closedById, action: AuditAction.DAY_CLOSE, entity: 'DailyClosing', entityId: closing.id, newValue: closing as any });
    return closing;
  }

  async reopen(date: Date, reason: string, actorId?: string) {
    const { start } = this.dayRange(date);
    const closing = await this.prisma.dailyClosing.findUnique({ where: { date: start } });
    if (!closing) throw new NotFoundException('بستن روزی برای بازکردن یافت نشد.');
    if (!reason) throw new BadRequestException('برای بازکردن روز، ذکر دلیل الزامی است.');

    const updated = await this.prisma.dailyClosing.update({
      where: { date: start },
      data: { isLocked: false, reopenReason: reason },
    });

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.DAY_REOPEN,
      entity: 'DailyClosing',
      entityId: updated.id,
      reason,
      oldValue: closing as any,
      newValue: updated as any,
    });

    return updated;
  }
}
