import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, DocumentType } from '@prisma/client';
import { DocumentSequenceService } from '../document-sequence/document-sequence.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';

/** ثبت خرید: مبلف بدهی باقی‌مانده به عنوان بدهی تامین‌کننده ثبت می‌شود. */
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

    const itemsData = dto.items.map((item) => ({
      itemName: item.itemName,
      quantity: item.quantity,
      unit: item.unit,
      unitPrice: item.unitPrice,
      lineTotal: item.quantity * item.unitPrice,
    }));

    let totalAmount = itemsData.reduce((sum, item) => sum + item.lineTotal, 0);
    totalAmount -= dto.discount ?? 0;
    if (totalAmount < 0) totalAmount = 0;

    const paidAmount = dto.paidAmount ?? totalAmount;
    const debtAmount = Math.max(totalAmount - paidAmount, 0);

    const docNumber = await this.documentSequenceService.next(DocumentType.PURCHASE);

    const purchase = await this.prisma.$transaction(async (tx) => {
      const created = await tx.purchase.create({
        data: {
          docNumber,
          invoiceNumber: dto.invoiceNumber,
          supplierId: dto.supplierId,
          category: dto.category,
          discount: dto.discount ?? 0,
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
        if (debtAmount > 0) {
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
