import { Test } from '@nestjs/testing';
import { NotificationType } from '@prisma/client';
import { ProductionService } from './production.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';

describe('ProductionService', () => {
  let service: ProductionService;
  let prisma: any;
  let auditLogService: { record: jest.Mock };

  beforeEach(async () => {
    prisma = {
      production: { create: jest.fn() },
      notification: { create: jest.fn() },
    };
    auditLogService = { record: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        ProductionService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = moduleRef.get(ProductionService);
  });

  it('وقتی نسبت ضایعات از آستانه بیشتر باشد باید اعلان ثبت شود', async () => {
    prisma.production.create.mockResolvedValue({
      id: 'prod-1',
      items: [{ producedQty: 100, wasteQty: 20, product: { name: 'نان بربری' } }],
    });

    await service.create(
      {
        date: '2026-01-01',
        shift: 'MORNING',
        items: [{ productId: 'p1', producedQty: 100, wasteQty: 20 }],
      } as any,
      'actor-1',
    );

    expect(prisma.notification.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ type: NotificationType.ABNORMAL_WASTE }) }),
    );
  });

  it('وقتی نسبت ضایعات طبیعی باشد نباید اعلان ثبت شود', async () => {
    prisma.production.create.mockResolvedValue({
      id: 'prod-2',
      items: [{ producedQty: 100, wasteQty: 2, product: { name: 'نان بربری' } }],
    });

    await service.create(
      {
        date: '2026-01-01',
        shift: 'MORNING',
        items: [{ productId: 'p1', producedQty: 100, wasteQty: 2 }],
      } as any,
      'actor-1',
    );

    expect(prisma.notification.create).not.toHaveBeenCalled();
  });
});
