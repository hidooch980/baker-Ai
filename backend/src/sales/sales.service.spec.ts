import { Prisma, PaymentMethodType } from '@prisma/client';
import { SalesService } from './sales.service';

/**
 * تست دقت اعشاری: جمع مبالغ باید با Prisma.Decimal انجام شود، نه number.
 * در جاوااسکریپت 0.1 + 0.2 === 0.30000000000000004 است؛ اگر این محاسبه با number انجام شود،
 * این تست شکست می‌خورد.
 */
describe('SalesService decimal precision', () => {
  it('sums decimal line totals without binary floating-point rounding error', async () => {
    let capturedTotalAmount: any;

    const prisma = {
      paymentMethod: { findUnique: jest.fn().mockResolvedValue({ id: 'pm-1', type: PaymentMethodType.CASH }) },
      product: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'p-1', prices: [{ price: new Prisma.Decimal('0.1') }] },
          { id: 'p-2', prices: [{ price: new Prisma.Decimal('0.2') }] },
        ]),
      },
      $transaction: jest.fn(async (fn: any) => {
        const tx = {
          sale: {
            create: jest.fn((args: any) => {
              capturedTotalAmount = args.data.totalAmount;
              return Promise.resolve({ id: 'sale-1', items: [], payments: [] });
            }),
          },
          cashBox: { findFirst: jest.fn().mockResolvedValue(null) },
          cashTransaction: { create: jest.fn() },
          customerTransaction: { create: jest.fn() },
          customer: { update: jest.fn() },
        };
        return fn(tx);
      }),
      sale: { findFirst: jest.fn().mockResolvedValue({ id: 'sale-1', totalAmount: new Prisma.Decimal('0.3') }) },
    } as any;

    const documentSequenceService = { next: jest.fn().mockResolvedValue('S-0001') } as any;
    const auditLogService = { record: jest.fn() } as any;

    const service = new SalesService(prisma, auditLogService, documentSequenceService);

    await service.create(
      {
        type: 'RETAIL' as any,
        items: [
          { productId: 'p-1', quantity: 1 },
          { productId: 'p-2', quantity: 1 },
        ],
        paymentMethodId: 'pm-1',
      } as any,
      'user-1',
    );

    expect(capturedTotalAmount).toBeInstanceOf(Prisma.Decimal);
    expect(capturedTotalAmount.toString()).toBe('0.3');
  });
});
