import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, Prisma } from '@prisma/client';

/**
 * مدیریت صندوق: باز کردن روز، ثبت دریافت/پرداخت نقدی، و بستن روز با مقایسه موجودی واقعی با موجودی محاسبه‌شده.
 * محاسبه موجودی با Prisma.Decimal انجام می‌شود تا خطای گرد کردن اعشار در تشخیص مغایرت صندوق رخ ندهد.
 */
@Injectable()
export class CashBoxService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  private dayStart(date: Date) {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);
    return d;
  }

  async getOpenCashBox() {
    const cashBox = await this.prisma.cashBox.findFirst({ where: { isClosed: false }, orderBy: { date: 'desc' } });
    if (!cashBox) throw new NotFoundException('هیچ صندوق بازی وجود ندارد.');
    return cashBox;
  }

  async openDay(date: Date, openingBalance: number, actorId?: string) {
    const day = this.dayStart(date);
    const existing = await this.prisma.cashBox.findUnique({ where: { date: day } });
    if (existing) throw new BadRequestException('صندوق این روز قبلاً باز شده است.');

    const cashBox = await this.prisma.cashBox.create({ data: { date: day, openingBalance } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'CashBox', entityId: cashBox.id, newValue: cashBox as any });
    return cashBox;
  }

  async addTransaction(cashBoxId: string, type: string, amount: number, note: string | undefined, actorId?: string) {
    const cashBox = await this.prisma.cashBox.findUnique({ where: { id: cashBoxId } });
    if (!cashBox) throw new NotFoundException('صندوق یافت نشد.');
    if (cashBox.isClosed) throw new BadRequestException('این روز قبلاً بسته شده است.');

    return this.prisma.cashTransaction.create({ data: { cashBoxId, type, amount, note, createdById: actorId } });
  }

  async calculateBalance(cashBoxId: string): Promise<InstanceType<typeof Prisma.Decimal>> {
    const cashBox = await this.prisma.cashBox.findUnique({
      where: { id: cashBoxId },
      include: { transactions: true },
    });
    if (!cashBox) throw new NotFoundException('صندوق یافت نشد.');

    const inflowTypes = new Set(['RECEIPT', 'SALE_CASH', 'DEBT_RECEIPT']);
    let calculated = new Prisma.Decimal(cashBox.openingBalance);
    for (const tx of cashBox.transactions) {
      const amount = new Prisma.Decimal(tx.amount);
      calculated = inflowTypes.has(tx.type) ? calculated.plus(amount) : calculated.minus(amount);
    }
    return calculated;
  }

  async closeDay(cashBoxId: string, actualClosingBalance: number, actorId?: string) {
    const cashBox = await this.prisma.cashBox.findUnique({ where: { id: cashBoxId } });
    if (!cashBox) throw new NotFoundException('صندوق یافت نشد.');
    if (cashBox.isClosed) throw new BadRequestException('این صندوق قبلاً بسته شده است.');

    const calculatedBalance = await this.calculateBalance(cashBoxId);
    const actual = new Prisma.Decimal(actualClosingBalance);
    const discrepancy = actual.minus(calculatedBalance);

    const updated = await this.prisma.cashBox.update({
      where: { id: cashBoxId },
      data: {
        closingBalance: actual,
        calculatedBalance,
        discrepancy,
        isClosed: true,
      },
    });

    if (discrepancy.abs().greaterThan(0.01)) {
      await this.prisma.notification.create({
        data: {
          type: 'CASH_DISCREPANCY',
          title: 'مغایرت موجودی صندوق',
          message: `موجودی واقعی با موجودی محاسبه‌شده ${discrepancy.toString()} ریال اختلاف دارد.`,
        },
      });
    }

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.DAY_CLOSE,
      entity: 'CashBox',
      entityId: cashBoxId,
      newValue: updated as any,
    });

    return updated;
  }
}
