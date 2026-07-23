import { Test } from '@nestjs/testing';
import { NotificationType } from '@prisma/client';
import { FlourInventoryService } from './flour-inventory.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';

describe('FlourInventoryService', () => {
  let service: FlourInventoryService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      flourInventory: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
      flourTransaction: { findMany: jest.fn() },
      doughBatch: { findMany: jest.fn() },
      notification: { create: jest.fn() },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        FlourInventoryService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();

    service = moduleRef.get(FlourInventoryService);
  });

  it('باید درصد انحراف مصرف واقعی از استاندارد را درست محاسبه کند', async () => {
    prisma.flourInventory.findFirst.mockResolvedValue({ id: 'fi-1', currentStockKg: 500, minStockKg: 100 });
    prisma.flourTransaction.findMany.mockResolvedValue([{ totalWeightKg: 100 }]);
    prisma.doughBatch.findMany.mockResolvedValue([{ doughWeightKg: 155 }]);

    const report = await service.getConsumptionReport(new Date('2026-01-01'), new Date('2026-01-31'));

    expect(report.realConsumptionKg).toBe(100);
    expect(report.standardConsumptionKg).toBeCloseTo(100, 5);
    expect(report.deviationPercent).toBeCloseTo(0, 3);
  });

  it('وقتی موجودی کمتر از حداقل باشد باید اعلان کمبود آرد ثبت شود', async () => {
    prisma.flourInventory.findFirst.mockResolvedValue({ id: 'fi-1', currentStockKg: 50, minStockKg: 100 });

    await service.checkLowStockAlert();

    expect(prisma.notification.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ type: NotificationType.LOW_FLOUR }) }),
    );
  });

  it('وقتی موجودی کافی باشد نباید اعلان ثبت شود', async () => {
    prisma.flourInventory.findFirst.mockResolvedValue({ id: 'fi-1', currentStockKg: 500, minStockKg: 100 });

    await service.checkLowStockAlert();

    expect(prisma.notification.create).not.toHaveBeenCalled();
  });
});
