import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SyncStatus } from '@prisma/client';
import { SalesService } from '../sales/sales.service';
import { ExpensesService } from '../expenses/expenses.service';
import { EmployeesService } from '../employees/employees.service';
import { ProductionService } from '../production/production.service';
import { SyncOperationDto } from './dto/sync-push.dto';

export type SyncOperationResult = {
  clientOperationId: string;
  status: 'SYNCED' | 'CONFLICT' | 'FAILED';
  serverId?: string;
  errorMessage?: string;
};

/**
 * موتور همگام‌سازی آفلاین/اوفلاین: عملیاتی که در حالت آفلاین روی موبایل در صف انتظار قرارگرفته‌اند،
 * بهمان منطق کسبی‌کاری سرویس‌های موجود (بدون دورزدن منطق) اجرا می‌شوند تا قواعد کسب‌وکار
 * (موجودی، بدهی، دفتر روزانه) رعایت شود.
 */
@Injectable()
export class SyncService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly salesService: SalesService,
    private readonly expensesService: ExpensesService,
    private readonly employeesService: EmployeesService,
    private readonly productionService: ProductionService,
  ) {}

  async push(clientId: string, operations: SyncOperationDto[], actorId?: string): Promise<SyncOperationResult[]> {
    const results: SyncOperationResult[] = [];

    for (const op of operations) {
      const queueItem = await this.prisma.syncQueue.create({
        data: {
          entity: op.entity,
          entityId: op.entityId ?? op.clientOperationId,
          operation: op.operation,
          payload: op.payload as any,
          clientId,
          status: SyncStatus.PENDING,
        },
      });

      try {
        const serverId = await this.applyOperation(op, actorId);
        await this.prisma.syncQueue.update({
          where: { id: queueItem.id },
          data: { status: SyncStatus.SYNCED, processedAt: new Date() },
        });
        results.push({ clientOperationId: op.clientOperationId, status: 'SYNCED', serverId });
      } catch (error: any) {
        const isConflict = error instanceof ConflictException;
        const status = isConflict ? SyncStatus.CONFLICT : SyncStatus.FAILED;
        const errorMessage = error?.message ?? 'خطای نامشخص در همگام‌سازی';
        await this.prisma.syncQueue.update({
          where: { id: queueItem.id },
          data: { status, errorMessage },
        });
        results.push({
          clientOperationId: op.clientOperationId,
          status: isConflict ? 'CONFLICT' : 'FAILED',
          errorMessage,
        });
      }
    }

    return results;
  }

  private async applyOperation(op: SyncOperationDto, actorId?: string): Promise<string> {
    if (op.operation !== 'CREATE') {
      throw new Error(`عملیات ${op.operation} برای ${op.entity} هنوز در همگام‌سازی پشتیبانی نمی‌شود.`);
    }

    switch (op.entity) {
      case 'Sale': {
        const sale = await this.salesService.create(op.payload as any, actorId);
        return sale.id;
      }
      case 'Expense': {
        const expense = await this.expensesService.create(op.payload as any, actorId);
        return expense.id;
      }
      case 'Attendance': {
        const payload = op.payload as { employeeId: string; date: string; status: any; overtimeHours?: number; note?: string };
        const attendance = await this.employeesService.recordAttendance(
          payload.employeeId,
          new Date(payload.date),
          payload.status,
          payload.overtimeHours,
          payload.note,
          actorId,
        );
        return attendance.id;
      }
      case 'Production': {
        const production = await this.productionService.create(op.payload as any, actorId);
        return production.id;
      }
      default:
        throw new Error('نوع موجودیت پشتیبانی نمی‌شود.');
    }
  }

  async queueStatus(clientId: string) {
    return this.prisma.syncQueue.findMany({
      where: { clientId },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  /** داده‌های مرجع مورد نیاز حالت آفلاین را از تاریخ مشخص‌شده به بعد برمی‌گرداند. */
  async pull(since: Date | null) {
    const where = since ? { createdAt: { gt: since } } : {};

    const [products, customers, suppliers, employees, paymentMethods, expenseCategories, notifications] = await Promise.all([
      this.prisma.product.findMany({ where: { ...where, deletedAt: null }, include: { prices: { where: { effectiveTo: null }, take: 1 } } }),
      this.prisma.customer.findMany({ where: { ...where, deletedAt: null } }),
      this.prisma.supplier.findMany({ where: { ...where, deletedAt: null } }),
      this.prisma.employee.findMany({ where: { ...where, deletedAt: null } }),
      this.prisma.paymentMethod.findMany(),
      this.prisma.expenseCategory.findMany(),
      this.prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' }, take: 50 }),
    ]);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayClosing = await this.prisma.dailyClosing.findUnique({ where: { date: today } });

    return {
      serverTime: new Date().toISOString(),
      isTodayLocked: todayClosing?.isLocked ?? false,
      changes: { products, customers, suppliers, employees, paymentMethods, expenseCategories, notifications },
    };
  }
}
