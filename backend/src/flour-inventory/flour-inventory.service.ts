import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, InventoryTxType, NotificationType } from '@prisma/client';

const STANDARD_YIELD_RATIO = 1.55;

/**
 * مدیریت انبار آرد: خرید/دریافت کیسه، کاهش موجودی هم‌زمان با تولید (از ماژول dough)، و گزارش مقایسه مصرف واقعی و استاندارد.
 */
@Injectable()
export class FlourInventoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async getOrCreate() {
    const existing = await this.prisma.flourInventory.findFirst();
    if (existing) return existing;
    return this.prisma.flourInventory.create({ data: { currentStockKg: 0, minStockKg: 0 } });
  }

  async setMinStock(minStockKg: number) {
    const inventory = await this.getOrCreate();
    return this.prisma.flourInventory.update({ where: { id: inventory.id }, data: { minStockKg } });
  }

  async addStock(data: {
    bagCount?: number;
    bagWeightKg?: number;
    totalWeightKg: number;
    pricePerBag?: number;
    totalPrice?: number;
    supplierId?: string;
    invoiceNumber?: string;
  }, actorId?: string) {
    const inventory = await this.getOrCreate();

    const transaction = await this.prisma.$transaction(async (tx) => {
      const created = await tx.flourTransaction.create({
        data: { ...data, flourInventoryId: inventory.id, type: InventoryTxType.PURCHASE, createdById: actorId },
      });
      await tx.flourInventory.update({ where: { id: inventory.id }, data: { currentStockKg: { increment: data.totalWeightKg } } });
      return created;
    });

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.CREATE,
      entity: 'FlourTransaction',
      entityId: transaction.id,
      newValue: transaction as any,
    });

    return transaction;
  }

  async getCurrentStock() {
    return this.getOrCreate();
  }

  /** مقایسه مصرف واقعی آرد (از FlourTransaction) با مصرف استاندارد محاسبه‌شده از وزن خمیر تولیدی در بازه زمانی. */
  async getConsumptionReport(startDate: Date, endDate: Date) {
    const inventory = await this.getOrCreate();

    const consumptionTx = await this.prisma.flourTransaction.findMany({
      where: { flourInventoryId: inventory.id, type: InventoryTxType.CONSUMPTION, date: { gte: startDate, lte: endDate } },
    });
    const realConsumptionKg = consumptionTx.reduce((sum, t) => sum + t.totalWeightKg, 0);

    const doughBatches = await this.prisma.doughBatch.findMany({
      where: { producedAt: { gte: startDate, lte: endDate } },
    });
    const totalDoughWeightKg = doughBatches.reduce((sum, b) => sum + b.doughWeightKg, 0);
    const standardConsumptionKg = totalDoughWeightKg / STANDARD_YIELD_RATIO;

    const deviationPercent = standardConsumptionKg > 0 ? ((realConsumptionKg - standardConsumptionKg) / standardConsumptionKg) * 100 : 0;

    return {
      realConsumptionKg,
      standardConsumptionKg,
      deviationPercent,
      currentStockKg: inventory.currentStockKg,
      minStockKg: inventory.minStockKg,
    };
  }

  async checkLowStockAlert() {
    const inventory = await this.getOrCreate();
    if (inventory.currentStockKg < inventory.minStockKg) {
      await this.prisma.notification.create({
        data: {
          type: NotificationType.LOW_FLOUR,
          title: 'موجودی آرد کم است',
          message: `موجودی فعلی آرد (${inventory.currentStockKg} کیلوگرم) از حد مجاز کمتر است.`,
        },
      });
    }
    return inventory;
  }
}
