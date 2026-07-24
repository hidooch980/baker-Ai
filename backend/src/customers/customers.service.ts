import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, NotificationType, Prisma } from '@prisma/client';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

/** مدیریت مشتریان و دفتر بدهکاران/بستانکاران. محاسبه مانده‌ها با Prisma.Decimal انجام می‌شود. */
@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  findAll() {
    return this.prisma.customer.findMany({ where: { deletedAt: null }, orderBy: { name: 'asc' } });
  }

  async findOne(id: string) {
    const customer = await this.prisma.customer.findFirst({
      where: { id, deletedAt: null },
      include: { transactions: { orderBy: { createdAt: 'desc' }, take: 50 } },
    });
    if (!customer) throw new NotFoundException('مشتری یافت نشد.');
    return customer;
  }

  async create(dto: CreateCustomerDto, actorId?: string) {
    const customer = await this.prisma.customer.create({ data: dto });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Customer', entityId: customer.id, newValue: customer as any });
    return customer;
  }

  async update(id: string, dto: UpdateCustomerDto, actorId?: string) {
    await this.findOne(id);
    const customer = await this.prisma.customer.update({ where: { id }, data: dto });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.UPDATE, entity: 'Customer', entityId: id, newValue: customer as any });
    return customer;
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.customer.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.DELETE, entity: 'Customer', entityId: id });
    return { success: true };
  }

  /** ثبت دریافت/بدهی/تسویه حساب. */
  async addTransaction(customerId: string, type: 'PAYMENT' | 'DEBT' | 'SETTLEMENT', amount: number, note: string | undefined, dueDate: Date | undefined, actorId?: string) {
    await this.findOne(customerId);
    const delta = type === 'PAYMENT' || type === 'SETTLEMENT' ? -amount : amount;

    const transaction = await this.prisma.$transaction(async (tx) => {
      const created = await tx.customerTransaction.create({ data: { customerId, type, amount, note, dueDate } });
      await tx.customer.update({ where: { id: customerId }, data: { balance: { increment: delta } } });
      return created;
    });

    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'CustomerTransaction', entityId: transaction.id, newValue: transaction as any });
    return transaction;
  }

  /** گزارش بدهکاران: مشتریانی با مانده حساب باز. */
  async debtReport() {
    const debtors = await this.prisma.customer.findMany({
      where: { deletedAt: null, balance: { gt: 0 } },
      orderBy: { balance: 'desc' },
    });
    const totalDebt = debtors
      .reduce((sum, c) => sum.plus(c.balance), new Prisma.Decimal(0))
      .toNumber();
    return { debtors, totalDebt };
  }

  /** بررسی بدهی‌های سررسیده و ارسال اعلان.
   */
  async checkOverdueDebts() {
    const overdue = await this.prisma.customerTransaction.findMany({
      where: { type: 'DEBT', dueDate: { lt: new Date() } },
      include: { customer: true },
    });
    for (const item of overdue) {
      if (new Prisma.Decimal(item.customer.balance).greaterThan(0)) {
        await this.prisma.notification.create({
          data: {
            type: NotificationType.DEBT_DUE,
            title: 'سررسید موعد بدهی',
            message: `بدهی مشتری "${item.customer.name}" از موعد مقرر گذشته است.`,
          },
        });
      }
    }
    return { checkedCount: overdue.length };
  }
}
