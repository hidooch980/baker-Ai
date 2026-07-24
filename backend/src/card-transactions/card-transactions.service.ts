import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

/**
 * تطبیق دستگاه کارتخوان (POS): تراکنش‌های وارده از دستگاه را با فروش‌های نقدی/کارتی ثبت‌شده در سیستم مقایسه می‌کند.
 * محاسبه با Prisma.Decimal انجام می‌شود تا خطای گرد کردن اعشار در تشخیص مغایرت رخ ندهد.
 */
@Injectable()
export class CardTransactionsService {
  constructor(private readonly prisma: PrismaService) {}

  create(data: { amount: number; occurredAt: Date; terminalId?: string; traceNumber?: string; refNumber?: string; createdById?: string }) {
    return this.prisma.cardTransaction.create({ data });
  }

  findByDate(date: Date) {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);
    return this.prisma.cardTransaction.findMany({ where: { occurredAt: { gte: start, lt: end } } });
  }

  async reconcileForDate(date: Date) {
    const transactions = await this.findByDate(date);
    const totalTerminal = transactions.reduce((sum, t) => sum.plus(t.amount), new Prisma.Decimal(0));

    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const paymentMethod = await this.prisma.paymentMethod.findFirst({ where: { name: 'کارتخوان' } });
    const cardPayments = paymentMethod
      ? await this.prisma.payment.findMany({
          where: { paymentMethodId: paymentMethod.id, createdAt: { gte: start, lt: end } },
        })
      : [];
    const totalSales = cardPayments.reduce((sum, p) => sum.plus(p.amount), new Prisma.Decimal(0));

    const discrepancy = totalTerminal.minus(totalSales);

    if (discrepancy.abs().greaterThan(0.01)) {
      await this.prisma.notification.create({
        data: {
          type: 'CARD_DISCREPANCY',
          title: 'مغایرت دستگاه کارتخوان',
          message: `مبلغ دستگاه کارتخوان با مبلغ فروش‌های کارتی تفاوت دارد (${discrepancy.toString()}).`,
        },
      });
    }

    return {
      totalTerminal: totalTerminal.toNumber(),
      totalSales: totalSales.toNumber(),
      discrepancy: discrepancy.toNumber(),
    };
  }
}
