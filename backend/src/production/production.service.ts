import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, NotificationType } from '@prisma/client';
import { CreateProductionDto } from './dto/create-production.dto';

/** آستانه خطای قابل قبول ضایعات نسبت به تولید (بالاتر از این یعنی مصرف نامطلوب). */
const WASTE_RATIO_THRESHOLD = 0.1;

@Injectable()
export class ProductionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async findAll() {
    return this.prisma.production.findMany({
      where: { deletedAt: null },
      include: { items: { include: { product: true } } },
      orderBy: { date: 'desc' },
      take: 100,
    });
  }

  async findOne(id: string) {
    const production = await this.prisma.production.findFirst({
      where: { id, deletedAt: null },
      include: { items: { include: { product: true } }, doughBatches: true },
    });
    if (!production) throw new NotFoundException('ریکورد تولید یافت نشد.');
    return production;
  }

  async create(dto: CreateProductionDto, actorId?: string) {
    const totalDough = dto.items.reduce((sum, item) => sum + item.producedQty, 0);

    const production = await this.prisma.production.create({
      data: {
        date: new Date(dto.date),
        shift: dto.shift,
        operatorId: dto.operatorId,
        notes: dto.notes,
        batchCount: totalDough,
        items: {
          create: dto.items.map((item) => ({
            productId: item.productId,
            producedQty: item.producedQty,
            wasteQty: item.wasteQty ?? 0,
            returnedQty: item.returnedQty ?? 0,
          })),
        },
      },
      include: { items: { include: { product: true } } },
    });

    for (const item of production.items) {
      const wasteRatio = item.producedQty > 0 ? item.wasteQty / item.producedQty : 0;
      if (wasteRatio > WASTE_RATIO_THRESHOLD) {
        await this.prisma.notification.create({
          data: {
            type: NotificationType.ABNORMAL_WASTE,
            title: 'ضایعات گیر بالا',
            message: `ضایعات محصول ‌"${item.product.name}" در تولید ${production.id} برابر با ${(wasteRatio * 100).toFixed(1)}٪ بوده است.`,
          },
        });
      }
    }

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.CREATE,
      entity: 'Production',
      entityId: production.id,
      newValue: production as any,
    });

    return production;
  }

  /** مقایسه تولید در برابر فروش و کاهش موجودی برای کشف ناهماهنگی تولید/فروش. */
  async productionVsSalesReport(productId: string, startDate: Date, endDate: Date) {
    const productionItems = await this.prisma.productionItem.findMany({
      where: { productId, production: { date: { gte: startDate, lte: endDate } } },
    });
    const totalProduced = productionItems.reduce((sum, i) => sum + i.producedQty, 0);
    const totalWaste = productionItems.reduce((sum, i) => sum + i.wasteQty, 0);

    const saleItems = await this.prisma.saleItem.findMany({
      where: { productId, sale: { date: { gte: startDate, lte: endDate }, status: 'ACTIVE' } },
    });
    const totalSold = saleItems.reduce((sum, i) => sum + i.quantity, 0);

    return {
      totalProduced,
      totalWaste,
      totalSold,
      unaccounted: totalProduced - totalWaste - totalSold,
    };
  }
}
