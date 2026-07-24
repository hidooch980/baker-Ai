import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, FuelType, InventoryTxType, NotificationType } from '@prisma/client';

const LOW_FUEL_RATIO = 0.15;

/** مدیریت مخازن سوخت: شارژ/مصرف و گزارش مصرف. */
@Injectable()
export class FuelService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  findAllTanks() {
    return this.prisma.fuelTank.findMany();
  }

  async createTank(fuelType: FuelType, capacityLiters: number) {
    return this.prisma.fuelTank.create({ data: { fuelType, capacityLiters, currentLiters: 0 } });
  }

  private async getTank(id: string) {
    const tank = await this.prisma.fuelTank.findUnique({ where: { id } });
    if (!tank) throw new NotFoundException('مخزن سوخت یافت نشد.');
    return tank;
  }

  async addFuel(tankId: string, liters: number, pricePerLiter: number | undefined, actorId?: string) {
    await this.getTank(tankId);
    const totalPrice = pricePerLiter ? pricePerLiter * liters : undefined;

    const transaction = await this.prisma.$transaction(async (tx) => {
      const created = await tx.fuelTransaction.create({
        data: { fuelTankId: tankId, type: InventoryTxType.RECEIVE, liters, pricePerLiter, totalPrice, createdById: actorId },
      });
      await tx.fuelTank.update({ where: { id: tankId }, data: { currentLiters: { increment: liters } } });
      return created;
    });

    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'FuelTransaction', entityId: transaction.id, newValue: transaction as any });
    return transaction;
  }

  async consumeFuel(tankId: string, liters: number, note: string | undefined, actorId?: string) {
    await this.getTank(tankId);

    const transaction = await this.prisma.$transaction(async (tx) => {
      const created = await tx.fuelTransaction.create({
        data: { fuelTankId: tankId, type: InventoryTxType.CONSUMPTION, liters, createdById: actorId },
      });
      await tx.fuelTank.update({ where: { id: tankId }, data: { currentLiters: { decrement: liters } } });
      return created;
    });

    const updatedTank = await this.getTank(tankId);
    if (updatedTank.currentLiters < updatedTank.capacityLiters * LOW_FUEL_RATIO) {
      await this.prisma.notification.create({
        data: {
          type: NotificationType.LOW_FUEL,
          title: 'موجودی سوخت کم است',
          message: `موجودی مخزن سوخت (${updatedTank.currentLiters} لیتر) زیر ۱۵٪ ظرفیت است.`,
        },
      });
    }

    await this.auditLogService.record({ userId: actorId, action: AuditAction.UPDATE, entity: 'FuelTransaction', entityId: transaction.id, newValue: transaction as any });
    return transaction;
  }

  async getConsumptionReport(tankId: string, startDate: Date, endDate: Date) {
    await this.getTank(tankId);
    const transactions = await this.prisma.fuelTransaction.findMany({
      where: { fuelTankId: tankId, type: InventoryTxType.CONSUMPTION, date: { gte: startDate, lte: endDate } },
    });
    const totalConsumedLiters = transactions.reduce((sum, t) => sum + t.liters, 0);
    const totalCost = transactions.reduce((sum, t) => sum + Number(t.totalPrice ?? 0), 0);
    return { totalConsumedLiters, totalCost, transactionCount: transactions.length };
  }
}
