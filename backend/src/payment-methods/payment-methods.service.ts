import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentMethodType } from '@prisma/client';

@Injectable()
export class PaymentMethodsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.paymentMethod.findMany({ where: { isActive: true } });
  }

  create(name: string, type: PaymentMethodType) {
    return this.prisma.paymentMethod.create({ data: { name, type } });
  }

  async ensureDefaults() {
    const defaults: Array<{ name: string; type: PaymentMethodType }> = [
      { name: 'نقدی', type: PaymentMethodType.CASH },
      { name: 'کارتخوان', type: PaymentMethodType.CARD },
      { name: 'نسیه/اعتباری', type: PaymentMethodType.CREDIT },
    ];
    for (const item of defaults) {
      const existing = await this.prisma.paymentMethod.findUnique({ where: { name: item.name } });
      if (!existing) {
        await this.prisma.paymentMethod.create({ data: item });
      }
    }
  }
}
