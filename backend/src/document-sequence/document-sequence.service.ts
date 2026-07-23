import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DocumentType } from '@prisma/client';

const DEFAULT_PREFIXES: Record<DocumentType, string> = {
  SALE: 'SL',
  PURCHASE: 'PU',
  EXPENSE: 'EX',
  PAYMENT: 'PY',
  DAILY_CLOSING: 'DC',
  CUSTOMER_TX: 'CT',
  SUPPLIER_TX: 'ST',
};

/**
 * تولیدکننده شماره سند خوحکار و منحصر‌به‌فرد. هر فراخوانی در یک ترانزکشن انجام می‌شود.
 */
@Injectable()
export class DocumentSequenceService {
  constructor(private readonly prisma: PrismaService) {}

  async next(type: DocumentType): Promise<string> {
    return this.prisma.$transaction(async (tx) => {
      let sequence = await tx.documentSequence.findUnique({ where: { type } });
      if (!sequence) {
        sequence = await tx.documentSequence.create({
          data: { type, prefix: DEFAULT_PREFIXES[type], lastValue: 0 },
        });
      }
      const nextValue = sequence.lastValue + 1;
      await tx.documentSequence.update({ where: { type }, data: { lastValue: nextValue } });
      const padded = String(nextValue).padStart(6, '0');
      return `${sequence.prefix}-${padded}`;
    });
  }
}
