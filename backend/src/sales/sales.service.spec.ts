import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { SalesService } from './sales.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { DocumentSequenceService } from '../document-sequence/document-sequence.service';

describe('SalesService', () => {
  let service: SalesService;
  let prisma: any;
  let auditLogService: { record: jest.Mock };

  beforeEach(async () => {
    prisma = {
      sale: { findFirst: jest.fn(), update: jest.fn() },
      customer: { update: jest.fn() },
    };
    auditLogService = { record: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        SalesService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLogService },
        { provide: DocumentSequenceService, useValue: { next: jest.fn() } },
      ],
    }).compile();

    service = moduleRef.get(SalesService);
  });

  it('لاطو کردن فروشی که قبلاً لاطو شده باید خطا بدهد', async () => {
    prisma.sale.findFirst.mockResolvedValue({
      id: 'sale-1',
      status: 'VOIDED',
      payments: [],
      totalAmount: 1000,
    });

    await expect(service.void('sale-1', 'دلیل تست', 'user-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.sale.update).not.toHaveBeenCalled();
  });

  it('لاطو کردن فروش نسیه‌ای باید بدهی مشتری را کاهش دهد', async () => {
    prisma.sale.findFirst
      .mockResolvedValueOnce({
        id: 'sale-1',
        status: 'ACTIVE',
        customerId: 'cust-1',
        totalAmount: 1000,
        payments: [{ amount: 400 }],
      })
      .mockResolvedValueOnce({
        id: 'sale-1',
        status: 'VOIDED',
        customerId: 'cust-1',
        totalAmount: 1000,
        payments: [{ amount: 400 }],
      });
    prisma.sale.update.mockResolvedValue({});
    prisma.customer.update.mockResolvedValue({});

    await service.void('sale-1', 'دلیل تست', 'user-1');

    expect(prisma.customer.update).toHaveBeenCalledWith({
      where: { id: 'cust-1' },
      data: { balance: { decrement: 600 } },
    });
    expect(auditLogService.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'VOID', reason: 'دلیل تست' }),
    );
  });
});
