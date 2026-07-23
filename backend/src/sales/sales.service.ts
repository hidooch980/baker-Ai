import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { DocumentSequenceService } from '../document-sequence/document-sequence.service';
import { AuditAction, DocumentType, PaymentMethodType, SaleStatus } from '@prisma/client';
import { CreateSaleDto } from './dto/create-sale.dto';

/**
 * ثبت فروش: قیمت فعلی محصول (اگر ارسال نشده) استفاده می‌شود، شماره سند به صورت خودکار ساخته می‌شود،
 * و اگر نوع پرداخت نسیه باشد، بدهی مشتری در دفتر بدهکاران ثبت و موجودی به‌روز می‌شود.
 */
@Injectable()
export class SalesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
    private readonly documentSequenceService: DocumentSequenceService,
  ) {}

  async findAll() {
    return this.prisma.sale.findMany({
      where: { deletedAt: null },
      include: { items: true, payments: true, customer: true },
      orderBy: { date: 'desc' },
      take: 100,
    });
  }

  async findOne(id: string) {
    const sale = await this.prisma.sale.findFirst({
      where: { id, deletedAt: null },
      include: { items: { include: { product: true } }, payments: { include: { paymentMethod: true } }, customer: true },
    });
    if (!sale) throw new NotFoundException('فروش یافت نشد.');
    return sale;
  }

  async create(dto: CreateSaleDto, actorId?: string) {
    const paymentMethod = await this.prisma.paymentMethod.findUnique({ where: { id: dto.paymentMethodId } });
    if (!paymentMethod) throw new BadRequestException('روش پرداخت معتبر نیست.');

    if (paymentMethod.type === PaymentMethodType.CREDIT && !dto.customerId) {
      throw new BadRequestException('برای فروش نسیه‌ای باید مشتری انتخاب شود.');
    }

    const productIds = dto.items.map((item) => item.productId);
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
      include: { prices: { where: { effectiveTo: null }, take: 1 } },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));

    let totalAmount = 0;
    const itemsData = dto.items.map((item) => {
      const product = productMap.get(item.productId);
      if (!product) throw new BadRequestException('یکی از محصولات یافت نشد.');
      const unitPrice = item.unitPrice ?? Number(product.prices[0]?.price ?? 0);
      const lineTotal = unitPrice * item.quantity - (item.discount ?? 0);
      totalAmount += lineTotal;
      return {
        productId: item.productId,
        quantity: item.quantity,
        unitPrice,
        discount: item.discount ?? 0,
        lineTotal,
      };
    });

    totalAmount -= dto.discount ?? 0;
    if (totalAmount < 0) totalAmount = 0;

    const docNumber = await this.documentSequenceService.next(DocumentType.SALE);
    const paidAmount = dto.paidAmount ?? totalAmount;

    const sale = await this.prisma.$transaction(async (tx) => {
      const created = await tx.sale.create({
        data: {
          docNumber,
          type: dto.type,
          status: SaleStatus.ACTIVE,
          discount: dto.discount ?? 0,
          totalAmount,
          customerId: dto.customerId,
          createdById: actorId,
          items: { create: itemsData },
          payments: {
            create: {
              amount: paidAmount,
              paymentMethodId: dto.paymentMethodId,
              direction: 'IN',
              customerId: dto.customerId,
            },
          },
        },
        include: { items: true, payments: true },
      });

      if (paymentMethod.type === PaymentMethodType.CASH) {
        const cashBox = await tx.cashBox.findFirst({ where: { isClosed: false }, orderBy: { date: 'desc' } });
        if (cashBox) {
          await tx.cashTransaction.create({
            data: { cashBoxId: cashBox.id, type: 'SALE_CASH', amount: paidAmount, note: `فروش ${docNumber}`, createdById: actorId },
          });
        }
      }

      if (dto.customerId) {
        const remainingDebt = totalAmount - paidAmount;
        if (remainingDebt > 0) {
          await tx.customerTransaction.create({
            data: { customerId: dto.customerId, type: 'DEBT', amount: remainingDebt, note: `بدهی فروش ${docNumber}` },
          });
          await tx.customer.update({ where: { id: dto.customerId }, data: { balance: { increment: remainingDebt } } });
        }
      }

      return created;
    });

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.CREATE,
      entity: 'Sale',
      entityId: sale.id,
      newValue: sale as any,
    });

    return this.findOne(sale.id);
  }

  async void(id: string, reason: string, actorId?: string) {
    const sale = await this.findOne(id);
    if (sale.status !== SaleStatus.ACTIVE) {
      throw new BadRequestException('این فروش قبلاً لاطو/برگشت شده است.');
    }

    await this.prisma.sale.update({ where: { id }, data: { status: SaleStatus.VOIDED } });

    if (sale.customerId) {
      const totalPaid = sale.payments.reduce((sum, p) => sum + Number(p.amount), 0);
      const remainingDebt = Number(sale.totalAmount) - totalPaid;
      if (remainingDebt > 0) {
        await this.prisma.customer.update({ where: { id: sale.customerId }, data: { balance: { decrement: remainingDebt } } });
      }
    }

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.VOID,
      entity: 'Sale',
      entityId: id,
      reason,
      oldValue: sale as any,
    });

    return this.findOne(id);
  }
}
