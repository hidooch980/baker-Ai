import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, DocumentType, Prisma } from '@prisma/client';
import { DocumentSequenceService } from '../document-sequence/document-sequence.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';

/**
 * ثبت خرید: مبلغ بدهی باقی‌مانده به عنوان بدهی تامین‌کننده ثبت می‌شود.
 * تمام محاسبات مبلغ با Prisma.Decimal انجام می‌شود تا خطای گرد کردن اعشار روی بدهی تامین‌کننده رخ ندهد.
 */
@Injectable()
export class PurchasesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
    private readonly documentSequenceService: DocumentSequenceService,
  ) {}

  async findAll() {
    return this.prisma.purchase.findMany({
      where: { deletedAt: null },
      include: { items: true, supplier: true },
      orderBy: { date: 'desc' },
      take: 100,
    });
  }

  async findOne(id: string) {
    const purchase = await this.prisma.purchase.findFirst({
      where: { id, deletedAt: null },
      include: { items: true, supplier: true },
    });
    if (!purchase) throw new NotFoundException('خرید یافت نشد.');
    return purchase;
  }

  async create(dto: CreatePurchaseDto, actorId?: string) {
    if (dto.supplierId) {
      const supplier = await this.prisma.supplier.findUnique({ where: { id: dto.supplierId } });
      if (!supplier) throw new BadRequestException('تامین‌کننده معتبر نیست.');
    }

    const itemsData = dto.items.map((item) => {
      const unitPrice = new Prisma.Decimal(item.unitPrice);
      const lineTotal = unitPrice.mul(item.quantity);
      return {
        itemName: item.itemName,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice,
        lineTotal,
      };
    });

    let totalAmount = itemsData.reduce((sum, item) => sum.plus(item.lineTotal), new Prisma.Decimal(0));
    const discount = new Prisma.Decimal(dto.discount ?? 0);
    totalAmount = totalAmount.minus(discount);
    if (totalAmount.isNegative()) totalAmount = new Prisma.Decimal(0);

    const paidAmount = dto.paidAmount !== undefined ? new Prisma.Decimal(dto.paidAmount) : totalAmount;
    const debtAmount = Prisma.Decimal.max(totalAmount.minus(paidAmount), 0);

    const docNumber = await this.documentSequenceService.next(DocumentType.PURCHASE);

    const purchase = await this.prisma.$transaction(async (tx) => {
      const created = await tx.purchase.create({
        data: {
          docNumber,
          invoiceNumber: dto.invoiceNumber,
          supplierId: dto.supplierId,
          category: dto.category,
          discount,
          totalAmount,
          paidAmount,
          debtAmount,
          createdById: actorId,
          items: { create: itemsData },
        },
        include: { items: true },
      });

      if (dto.supplierId) {
        await tx.supplierTransaction.create({
          data: { supplierId: dto.supplierId, type: 'PURCHASE', amount: totalAmount, note: `خرید ${docNumber}` },
        });
        if (debtAmount.greaterThan(0)) {
          await tx.supplierTransaction.create({
            data: { supplierId: dto.supplierId, type: 'DEBT', amount: debtAmount, note: `بدهی خرید ${docNumber}` },
          });
          await tx.supplier.update({ where: { id: dto.supplierId }, data: { balance: { increment: debtAmount } } });
        }
      }

      return created;
    });

    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Purchase', entityId: purchase.id, newValue: purchase as any });
    return this.findOne(purchase.id);
  }
}
