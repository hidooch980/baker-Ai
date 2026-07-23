import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';

/** مدیریت تامین‌کنندگان و حساب بدهی به آنها. */
@Injectable()
export class SuppliersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  findAll() {
    return this.prisma.supplier.findMany({ where: { deletedAt: null }, orderBy: { name: 'asc' } });
  }

  async findOne(id: string) {
    const supplier = await this.prisma.supplier.findFirst({
      where: { id, deletedAt: null },
      include: { transactions: { orderBy: { createdAt: 'desc' }, take: 50 } },
    });
    if (!supplier) throw new NotFoundException('تامین‌کننده یافت نشد.');
    return supplier;
  }

  async create(dto: CreateSupplierDto, actorId?: string) {
    const supplier = await this.prisma.supplier.create({ data: dto });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Supplier', entityId: supplier.id, newValue: supplier as any });
    return supplier;
  }

  async update(id: string, dto: UpdateSupplierDto, actorId?: string) {
    await this.findOne(id);
    const supplier = await this.prisma.supplier.update({ where: { id }, data: dto });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.UPDATE, entity: 'Supplier', entityId: id, newValue: supplier as any });
    return supplier;
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.supplier.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.DELETE, entity: 'Supplier', entityId: id });
    return { success: true };
  }

  async recordPayment(supplierId: string, amount: number, paymentMethodId: string, actorId?: string) {
    await this.findOne(supplierId);

    const payment = await this.prisma.$transaction(async (tx) => {
      const created = await tx.payment.create({ data: { supplierId, amount, paymentMethodId, direction: 'OUT' } });
      await tx.supplierTransaction.create({ data: { supplierId, type: 'PAYMENT', amount, note: 'پرداخت به تامین‌کننده' } });
      await tx.supplier.update({ where: { id: supplierId }, data: { balance: { decrement: amount } } });
      return created;
    });

    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Payment', entityId: payment.id, newValue: payment as any });
    return payment;
  }

  async debtReport() {
    const creditors = await this.prisma.supplier.findMany({
      where: { deletedAt: null, balance: { gt: 0 } },
      orderBy: { balance: 'desc' },
    });
    const totalPayable = creditors.reduce((sum, s) => sum + Number(s.balance), 0);
    return { creditors, totalPayable };
  }
}
