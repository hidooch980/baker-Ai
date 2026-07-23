import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { DailyClosingService } from './daily-closing.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';

describe('DailyClosingService', () => {
  let service: DailyClosingService;
  let prisma: any;
  let auditLogService: { record: jest.Mock };

  beforeEach(async () => {
    prisma = {
      dailyClosing: { findUnique: jest.fn(), upsert: jest.fn(), update: jest.fn() },
    };
    auditLogService = { record: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        DailyClosingService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = moduleRef.get(DailyClosingService);
  });

  it('بستن روزی که قبلاً قفل شده باید خطا بدهد', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue({ isLocked: true });

    await expect(service.closeDay(new Date('2026-01-01'), 'user-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.dailyClosing.upsert).not.toHaveBeenCalled();
  });

  it('بازکردن روز بدون ذکر دلیل باید خطا بدهد', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue({ id: 'dc-1', isLocked: true });

    await expect(service.reopen(new Date('2026-01-01'), '', 'user-1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('بازکردن روزی که وجود ندارد باید خطای یافت نشد بدهد', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue(null);

    await expect(service.reopen(new Date('2026-01-01'), 'دلیل تست', 'user-1')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('بازکردن روز معتبر باید isLocked را false کند و در لاگ حسابرسی ثبت شود', async () => {
    prisma.dailyClosing.findUnique.mockResolvedValue({ id: 'dc-1', isLocked: true });
    prisma.dailyClosing.update.mockResolvedValue({ id: 'dc-1', isLocked: false, reopenReason: 'دلیل تست' });

    const result = await service.reopen(new Date('2026-01-01'), 'دلیل تست', 'user-1');

    expect(result.isLocked).toBe(false);
    expect(auditLogService.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'DAY_REOPEN', reason: 'دلیل تست' }),
    );
  });
});
