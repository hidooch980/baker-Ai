import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * تطبیق دستگاه کارتخوان (POS): تراکنش‌های وارده از دستگاه را با فروش‌های نقدی/کارتی ثبت‌شده در سیستم مقایسه می‌کند.
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
    const totalTerminal = transactions.reduce((sum, t) => sum + Number(t.amount), 0);

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
    const totalSales = cardPayments.reduce((sum, p) => sum + Number(p.amount), 0);

    const discrepancy = totalTerminal - totalSales;

    if (Math.abs(discrepancy) > 0.01) {
      await this.prisma.notification.create({
        data: {
          type: 'CARD_DISCREPANCY',
          title: 'مفایرت دستگاه کارتخوان',
          message: `مبلف دستگاه کارتخوان با مبلف فروش‌های کارتی تفاوت دارد (${discrepancy}).`,
        },
      });
    }

    return { totalTerminal, totalSales, discrepancy };
  }
}
