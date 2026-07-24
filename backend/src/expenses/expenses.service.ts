import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, PaymentMethodType, Prisma } from '@prisma/client';
import { CreateExpenseDto } from './dto/create-expense.dto';

/** ثبت هزینه‌ها، شامل برداشت شخصی مدیر. اگر پرداخت نقدی باشد، از صندوق باز کسر می‌شود. */
@Injectable()
export class ExpensesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async findAll() {
    return this.prisma.expense.findMany({
      where: { deletedAt: null },
      include: { category: true },
      orderBy: { date: 'desc' },
      take: 100,
    });
  }

  async findAllCategories() {
    return this.prisma.expenseCategory.findMany({ orderBy: { name: 'asc' } });
  }

  async findOne(id: string) {
    const expense = await this.prisma.expense.findFirst({ where: { id, deletedAt: null }, include: { category: true } });
    if (!expense) throw new NotFoundException('هزینه یافت نشد.');
    return expense;
  }

  async create(dto: CreateExpenseDto, actorId?: string) {
    const category = await this.prisma.expenseCategory.findUnique({ where: { id: dto.categoryId } });
    const isPersonal = dto.isPersonal ?? category?.isPersonal ?? false;

    const expense = await this.prisma.$transaction(async (tx) => {
      const created = await tx.expense.create({
        data: {
          title: dto.title,
          amount: dto.amount,
          date: dto.date ? new Date(dto.date) : undefined,
          categoryId: dto.categoryId,
          paymentMethodId: dto.paymentMethodId,
          description: dto.description,
          receiptFileUrl: dto.receiptFileUrl,
          isPersonal,
          createdById: actorId,
        },
      });

      if (dto.paymentMethodId) {
        const paymentMethod = await tx.paymentMethod.findUnique({ where: { id: dto.paymentMethodId } });
        if (paymentMethod?.type === PaymentMethodType.CASH) {
          const cashBox = await tx.cashBox.findFirst({ where: { isClosed: false }, orderBy: { date: 'desc' } });
          if (cashBox) {
            await tx.cashTransaction.create({
              data: {
                cashBoxId: cashBox.id,
                type: isPersonal ? 'MANAGER_WITHDRAWAL' : 'EXPENSE',
                amount: dto.amount,
                note: dto.title,
                createdById: actorId,
              },
            });
          }
        }
      }

      return created;
    });

    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Expense', entityId: expense.id, newValue: expense as any });
    return this.findOne(expense.id);
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.expense.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.DELETE, entity: 'Expense', entityId: id });
    return { success: true };
  }

  async report(startDate: Date, endDate: Date) {
    const expenses = await this.prisma.expense.findMany({
      where: { deletedAt: null, date: { gte: startDate, lte: endDate } },
      include: { category: true },
    });
    const totalAmount = expenses.reduce(
      (sum, e) => sum.plus(e.amount),
      new Prisma.Decimal(0),
    );
    const personalAmount = expenses
      .filter((e) => e.isPersonal)
      .reduce((sum, e) => sum.plus(e.amount), new Prisma.Decimal(0));
    const byCategory = expenses.reduce<Record<string, Prisma.Decimal>>((acc, e) => {
      const current = acc[e.category.name] ?? new Prisma.Decimal(0);
      acc[e.category.name] = current.plus(e.amount);
      return acc;
    }, {});
    return {
      totalAmount: totalAmount.toNumber(),
      personalAmount: personalAmount.toNumber(),
      byCategory: Object.fromEntries(
        Object.entries(byCategory).map(([name, value]) => [name, value.toNumber()]),
      ),
    };
  }
}
