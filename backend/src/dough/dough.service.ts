import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, InventoryTxType, NotificationType } from '@prisma/client';
import { CreateDoughBatchDto } from './dto/create-dough-batch.dto';

/**
 * نرخ استاندارد بازدهی تولید خمیر (وزن خمیر به ازای وزن آرد مصرفی). مقدار تجربی است و می‌تواند توسط مدیر تنظیم شود.
 */
const STANDARD_YIELD_RATIO = 1.55;
const ABNORMAL_DEVIATION_THRESHOLD = 0.05;

@Injectable()
export class DoughService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  private async getOrCreateFlourInventory() {
    const existing = await this.prisma.flourInventory.findFirst();
    if (existing) return existing;
    return this.prisma.flourInventory.create({ data: { currentStockKg: 0, minStockKg: 0 } });
  }

  async findAll() {
    return this.prisma.doughBatch.findMany({ include: { divisions: true }, orderBy: { producedAt: 'desc' }, take: 100 });
  }

  async create(dto: CreateDoughBatchDto, actorId?: string) {
    const flourInventory = await this.getOrCreateFlourInventory();
    if (flourInventory.currentStockKg < dto.flourKg) {
      throw new BadRequestException('موجودی انبار آرد کافی نیست.');
    }

    const doughBatch = await this.prisma.$transaction(async (tx) => {
      const batch = await tx.doughBatch.create({
        data: {
          productionId: dto.productionId,
          flourKg: dto.flourKg,
          waterLiters: dto.waterLiters,
          saltKg: dto.saltKg,
          yeastKg: dto.yeastKg,
          doughWeightKg: dto.doughWeightKg,
          divisions: dto.divisions ? { create: dto.divisions } : undefined,
        },
        include: { divisions: true },
      });

      await tx.flourInventory.update({
        where: { id: flourInventory.id },
        data: { currentStockKg: { decrement: dto.flourKg } },
      });

      await tx.flourTransaction.create({
        data: {
          flourInventoryId: flourInventory.id,
          type: InventoryTxType.CONSUMPTION,
          totalWeightKg: dto.flourKg,
          createdById: actorId,
        },
      });

      return batch;
    });

    const standardDoughWeight = dto.flourKg * STANDARD_YIELD_RATIO;
    const deviation = (dto.doughWeightKg - standardDoughWeight) / standardDoughWeight;
    if (Math.abs(deviation) > ABNORMAL_DEVIATION_THRESHOLD) {
      await this.prisma.notification.create({
        data: {
          type: NotificationType.ABNORMAL_FLOUR_CONSUMPTION,
          title: 'انحراف مصرف آرد',
          message: `وزن خمیر تولیدشده (${dto.doughWeightKg} کیلوگرم) با مقدار استاندارد (${standardDoughWeight.toFixed(1)} کیلوگرم) بیش از ${(ABNORMAL_DEVIATION_THRESHOLD * 100).toFixed(0)}٪ تفاوت دارد.`,
        },
      });
    }

    const flourInventoryAfter = await this.prisma.flourInventory.findUnique({ where: { id: flourInventory.id } });
    if (flourInventoryAfter && flourInventoryAfter.currentStockKg < flourInventoryAfter.minStockKg) {
      await this.prisma.notification.create({
        data: {
          type: NotificationType.LOW_FLOUR,
          title: 'موجودی آرد کم است',
          message: `موجودی فعلی آرد (${flourInventoryAfter.currentStockKg} کیلوگرم) از حد مجاز کمتر است.`,
        },
      });
    }

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.CREATE,
      entity: 'DoughBatch',
      entityId: doughBatch.id,
      newValue: doughBatch as any,
    });

    return doughBatch;
  }
}
