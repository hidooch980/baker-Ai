import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, InventoryTxType, NotificationType } from '@prisma/client';

/** مدیریت مواد اولیه متفرقه (بجز آرد و سوخت که ماژول تخصصی دارند). */
@Injectable()
export class InventoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  findAll() {
    return this.prisma.inventory.findMany({ where: { deletedAt: null }, orderBy: { name: 'asc' } });
  }

  async findOne(id: string) {
    const item = await this.prisma.inventory.findFirst({ where: { id, deletedAt: null } });
    if (!item) throw new NotFoundException('ماده یافت نشد.');
    return item;
  }

  async create(data: { name: string; unit: string; minStock?: number; price?: number; supplierId?: string }, actorId?: string) {
    const existing = await this.prisma.inventory.findUnique({ where: { name: data.name } });
    if (existing) throw new ConflictException('ماده‌ای با این نام قبلاً ثبت شده است.');
    const item = await this.prisma.inventory.create({ data: { ...data, minStock: data.minStock ?? 0 } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Inventory', entityId: item.id, newValue: item as any });
    return item;
  }

  async adjustStock(id: string, type: InventoryTxType, quantity: number, note: string | undefined, actorId?: string) {
    const item = await this.findOne(id);
    const isIncrease = [InventoryTxType.INITIAL, InventoryTxType.PURCHASE, InventoryTxType.RECEIVE].includes(type);
    const delta = isIncrease ? quantity : -quantity;

    const updated = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.inventory.update({ where: { id }, data: { currentStock: { increment: delta } } });
      await tx.inventoryTransaction.create({ data: { inventoryId: id, type, quantity, note, createdById: actorId } });
      return changed;
    });

    if (updated.currentStock < updated.minStock) {
      await this.prisma.notification.create({
        data: {
          type: NotificationType.LOW_MATERIAL,
          title: 'موجودی کم ماده اولیه',
          message: `موجودی "${item.name}" (${updated.currentStock} ${item.unit}) از حد مجاز کمتر است.`,
        },
      });
    }

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.INVENTORY_ADJUSTMENT,
      entity: 'Inventory',
      entityId: id,
      oldValue: { currentStock: item.currentStock } as any,
      newValue: { currentStock: updated.currentStock } as any,
    });

    return updated;
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.inventory.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.DELETE, entity: 'Inventory', entityId: id });
    return { success: true };
  }
}
