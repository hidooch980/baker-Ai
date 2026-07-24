import { SyncService } from './sync.service';
import { SyncOperationDto } from './dto/sync-push.dto';

/**
 * تست ایدمپوتنسی همگام‌سازی: در سناریوی at-least-once delivery (رسیدن درخواست به سرور
 * و گم‌شدن پاسخ در راه بازگشت)، ارسال مجدد همان عملیات نباید دوباره اعمال شود.
 */
describe('SyncService idempotency', () => {
  const op: SyncOperationDto = {
    clientOperationId: 'op-1',
    entity: 'Sale',
    operation: 'CREATE',
    payload: { paymentMethodId: 'pm-1', items: [] },
  };

  function buildService(prisma: any, sales: any) {
    return new SyncService(prisma, sales, {} as any, {} as any, {} as any);
  }

  it('does not re-apply an operation that is already SYNCED and returns the previous serverId', async () => {
    const prisma = {
      syncQueue: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'queue-1',
          status: 'SYNCED',
          serverId: 'sale-1',
          createdAt: new Date(),
        }),
        create: jest.fn(),
        update: jest.fn(),
      },
    } as any;
    const sales = { create: jest.fn() } as any;

    const service = buildService(prisma, sales);
    const results = await service.push('client-1', [op], 'user-1');

    expect(results).toEqual([
      { clientOperationId: 'op-1', status: 'SYNCED', serverId: 'sale-1' },
    ]);
    expect(sales.create).not.toHaveBeenCalled();
    expect(prisma.syncQueue.create).not.toHaveBeenCalled();
  });

  it('applies a new operation once and stores its serverId for future retries', async () => {
    const prisma = {
      syncQueue: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'queue-1' }),
        update: jest.fn().mockResolvedValue({}),
      },
    } as any;
    const sales = { create: jest.fn().mockResolvedValue({ id: 'sale-9' }) } as any;

    const service = buildService(prisma, sales);
    const results = await service.push('client-1', [op], 'user-1');

    expect(results[0]).toEqual({ clientOperationId: 'op-1', status: 'SYNCED', serverId: 'sale-9' });
    expect(sales.create).toHaveBeenCalledTimes(1);
    expect(prisma.syncQueue.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'queue-1' },
        data: expect.objectContaining({ status: 'SYNCED', serverId: 'sale-9' }),
      }),
    );
  });

  it('skips a fresh PENDING duplicate (parallel request in flight) without re-applying', async () => {
    const prisma = {
      syncQueue: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'queue-1',
          status: 'PENDING',
          serverId: null,
          createdAt: new Date(),
        }),
        create: jest.fn(),
        update: jest.fn(),
      },
    } as any;
    const sales = { create: jest.fn() } as any;

    const service = buildService(prisma, sales);
    const results = await service.push('client-1', [op], 'user-1');

    expect(results[0].status).toBe('PENDING');
    expect(sales.create).not.toHaveBeenCalled();
  });

  it('retries a stale PENDING operation (previous attempt crashed mid-way)', async () => {
    const prisma = {
      syncQueue: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'queue-1',
          status: 'PENDING',
          serverId: null,
          createdAt: new Date(Date.now() - 30 * 60 * 1000),
        }),
        create: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
      },
    } as any;
    const sales = { create: jest.fn().mockResolvedValue({ id: 'sale-5' }) } as any;

    const service = buildService(prisma, sales);
    const results = await service.push('client-1', [op], 'user-1');

    expect(results[0]).toEqual({ clientOperationId: 'op-1', status: 'SYNCED', serverId: 'sale-5' });
    expect(sales.create).toHaveBeenCalledTimes(1);
    expect(prisma.syncQueue.create).not.toHaveBeenCalled();
  });
});
