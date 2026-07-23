import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';

/**
 * قوانین مهم: تاریخچه قیمت هرگز حذف نمی‌شود. تفییر قیمت یعنی بستن ردیف قبلی (effectiveTo) و باز کردن ردیف جدید.
 */
@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  private includeCurrentPrice() {
    return {
      prices: {
        where: { effectiveTo: null },
        orderBy: { effectiveFrom: 'desc' as const },
        take: 1,
      },
    };
  }

  async findAll() {
    return this.prisma.product.findMany({
      where: { deletedAt: null },
      include: this.includeCurrentPrice(),
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const product = await this.prisma.product.findFirst({
      where: { id, deletedAt: null },
      include: { prices: { orderBy: { effectiveFrom: 'desc' } } },
    });
    if (!product) throw new NotFoundException('محصول یافت نشد.');
    return product;
  }

  async create(dto: CreateProductDto, actorId?: string) {
    const existing = await this.prisma.product.findUnique({ where: { code: dto.code } });
    if (existing) throw new ConflictException('کد محصول قبلاً ثبت شده است.');

    const product = await this.prisma.product.create({
      data: {
        code: dto.code,
        name: dto.name,
        type: dto.type,
        weightGrams: dto.weightGrams,
        unit: dto.unit ?? 'عدد',
        prices: { create: { price: dto.price } },
      },
      include: this.includeCurrentPrice(),
    });

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.CREATE,
      entity: 'Product',
      entityId: product.id,
      newValue: product as any,
    });

    return product;
  }

  async update(id: string, dto: UpdateProductDto, actorId?: string) {
    const before = await this.findOne(id);

    await this.prisma.product.update({
      where: { id },
      data: {
        name: dto.name,
        type: dto.type,
        weightGrams: dto.weightGrams,
        unit: dto.unit,
      },
    });

    if (dto.price !== undefined) {
      const currentPrice = before.prices.find((p) => p.effectiveTo === null);
      const now = new Date();
      if (currentPrice) {
        await this.prisma.productPrice.update({ where: { id: currentPrice.id }, data: { effectiveTo: now } });
      }
      await this.prisma.productPrice.create({
        data: { productId: id, price: dto.price, effectiveFrom: now },
      });

      await this.auditLogService.record({
        userId: actorId,
        action: AuditAction.PRICE_CHANGE,
        entity: 'Product',
        entityId: id,
        oldValue: { price: currentPrice?.price } as any,
        newValue: { price: dto.price } as any,
      });
    }

    const after = await this.findOne(id);
    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.UPDATE,
      entity: 'Product',
      entityId: id,
      oldValue: before as any,
      newValue: after as any,
    });
    return after;
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.product.update({ where: { id }, data: { isActive: false, deletedAt: new Date() } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.DELETE, entity: 'Product', entityId: id });
    return { success: true };
  }
}
