import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SyncQueue, SyncStatus } from '@prisma/client';
import { SalesService } from '../sales/sales.service';
import { ExpensesService } from '../expenses/expenses.service';
import { EmployeesService } from '../employees/employees.service';
import { ProductionService } from '../production/production.service';
import { SyncOperationDto } from './dto/sync-push.dto';

export type SyncOperationResult = {
  clientOperationId: string;
  status: 'SYNCED' | 'CONFLICT' | 'FAILED' | 'PENDING';
  serverId?: string;
  errorMessage?: string;
};

/**
 * اگر یک عملیات PENDING قدیمی‌تر از این مقدار باشد، فرض می‌کنیم پردازش قبلی آن ناتمام مانده
 * (مثلاً کرش سرور در میانه کار) و تلاش مجدد مجاز است؛ سرویس‌های کسب‌وکار تراکنشی هستند و
 * کرش در میانه اعمال، تغییرات ناقص باقی نمی‌گذارد.
 */
const STALE_PENDING_MS = 10 * 60 * 1000;

/**
 * موتور همگام‌سازی آفلاین/آنلاین: عملیاتی که در حالت آفلاین روی موبایل در صف انتظار قرارگرفته‌اند،
 * با همان منطق کسب‌وکاری سرویس‌های موجود (بدون دورزدن منطق) اجرا می‌شوند تا قواعد کسب‌وکار
 * (موجودی، بدهی، دفتر روزانه) رعایت شود.
 *
 * ایدمپوتنسی (at-least-once delivery): هر عملیات با clientOperationId یکتا ردیابی می‌شود.
 * اگر درخواست به سرور برسد ولی پاسخ به دلیل قطعی شبکه به موبایل نرسد، ارسال مجدد همان عملیات
 * هرگز دوباره اعمال نمی‌شود؛ فقط نتیجه قبلی (SYNCED + serverId) برگردانده می‌شود.
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
      results.push(await this.processOperation(clientId, op, actorId));
    }
    return results;
  }

  private async processOperation(clientId: string, op: SyncOperationDto, actorId?: string): Promise<SyncOperationResult> {
    // ۱) بررسی ایدمپوتنسی: آیا این عملیات قبلاً با همین clientOperationId دریافت شده است؟
    const existing = await this.prisma.syncQueue.findUnique({
      where: { clientOperationId: op.clientOperationId },
    });
    if (existing) {
      return this.resolveExisting(existing, op, actorId);
    }

    // ۲) ثبت ردیف صف با کلید یکتا؛ در رقابت بین دو درخواست همزمان فقط یکی موفق می‌شود.
    let queueItem: SyncQueue;
    try {
      queueItem = await this.prisma.syncQueue.create({
        data: {
          entity: op.entity,
          entityId: op.entityId ?? op.clientOperationId,
          operation: op.operation,
          payload: op.payload as any,
          clientId,
          clientOperationId: op.clientOperationId,
          status: SyncStatus.PENDING,
        },
      });
    } catch (error: any) {
      if (error?.code === 'P2002') {
        // درخواست موازی دیگری همین عملیات را هم‌زمان ثبت کرده است.
        const duplicate = await this.prisma.syncQueue.findUnique({
          where: { clientOperationId: op.clientOperationId },
        });
        if (duplicate) {
          return this.resolveExisting(duplicate, op, actorId);
        }
      }
      throw error;
    }

    return this.applyAndRecord(queueItem.id, op, actorId);
  }

  /** برخورد با عملیاتی که قبلاً با همین clientOperationId دریافت شده است. */
  private async resolveExisting(existing: SyncQueue, op: SyncOperationDto, actorId?: string): Promise<SyncOperationResult> {
    if (existing.status === SyncStatus.SYNCED) {
      // قبلاً با موفقیت اعمال شده (پاسخ قبلی احتمالاً به موبایل نرسیده)؛ بدون اجرای مجدد همان نتیجه برگردانده می‌شود.
      return {
        clientOperationId: op.clientOperationId,
        status: 'SYNCED',
        serverId: existing.serverId ?? undefined,
      };
    }

    if (existing.status === SyncStatus.PENDING) {
      const ageMs = Date.now() - existing.createdAt.getTime();
      if (ageMs < STALE_PENDING_MS) {
        // احتمالاً همین عملیات در یک درخواست موازی در حال پردازش است؛ برای جلوگیری از ثبت تکراری اجرا نمی‌کنیم.
        return {
          clientOperationId: op.clientOperationId,
          status: 'PENDING',
          errorMessage: 'این عملیات قبلاً دریافت شده و در حال پردازش است؛ وضعیت آن در همگام‌سازی بعدی مشخص می‌شود.',
        };
      }
      // ردیف PENDING قدیمی: پردازش قبلی ناتمام مانده است و تلاش مجدد امن است.
    }

    // CONFLICT / FAILED / PENDING قدیمی: تلاش مجدد روی همان ردیف صف (بدون ساخت ردیف جدید).
    return this.applyAndRecord(existing.id, op, actorId);
  }

  /** اعمال عملیات و ثبت نتیجه (موفق یا ناموفق) روی همان ردیف صف. */
  private async applyAndRecord(queueItemId: string, op: SyncOperationDto, actorId?: string): Promise<SyncOperationResult> {
    try {
      const serverId = await this.applyOperation(op, actorId);
      await this.prisma.syncQueue.update({
        where: { id: queueItemId },
        data: { status: SyncStatus.SYNCED, serverId, errorMessage: null, processedAt: new Date() },
      });
      return { clientOperationId: op.clientOperationId, status: 'SYNCED', serverId };
    } catch (error: any) {
      const isConflict = error instanceof ConflictException;
      const status = isConflict ? SyncStatus.CONFLICT : SyncStatus.FAILED;
      const errorMessage = error?.message ?? 'خطای نامشخص در همگام‌سازی';
      await this.prisma.syncQueue.update({
        where: { id: queueItemId },
        data: { status, errorMessage },
      });
      return {
        clientOperationId: op.clientOperationId,
        status: isConflict ? 'CONFLICT' : 'FAILED',
        errorMessage,
      };
    }
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
