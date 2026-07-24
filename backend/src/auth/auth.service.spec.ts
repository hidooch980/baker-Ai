import { Test } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: any;
  let auditLogService: { record: jest.Mock };
  let jwtService: { signAsync: jest.Mock; verifyAsync: jest.Mock };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      refreshToken: {
        create: jest.fn().mockResolvedValue({}),
        findUnique: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    auditLogService = { record: jest.fn() };
    jwtService = { signAsync: jest.fn().mockResolvedValue('signed-token'), verifyAsync: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLogService },
        { provide: JwtService, useValue: jwtService },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) =>
              ({
                'jwt.accessSecret': 'secret',
                'jwt.accessExpiresIn': '15m',
                'jwt.refreshSecret': 'refresh-secret',
                'jwt.refreshExpiresIn': '7d',
              } as Record<string, string>)[key],
            ),
          },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('یک کاربر معتبر با رمز صحیح باید توکن دریافت کند و رفرش‌توکن در دیتابیس ذخیره شود', async () => {
    const passwordHash = await bcrypt.hash('secret123', 10);
    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      phone: '09120000000',
      passwordHash,
      isActive: true,
      deletedAt: null,
      fullName: 'کاربر تست',
    });
    prisma.user.update.mockResolvedValue({});

    const result = await service.login('09120000000', 'secret123', '127.0.0.1', 'jest-agent');

    expect(result.accessToken).toBe('signed-token');
    expect(result.refreshToken).toBe('signed-token');
    expect(prisma.refreshToken.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ userId: 'user-1' }) }),
    );
    expect(auditLogService.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'LOGIN', entity: 'User', entityId: 'user-1' }),
    );
  });

  it('رمز عبور اشتباه باید خطای عدم تایید هویت برگرداند', async () => {
    const passwordHash = await bcrypt.hash('secret123', 10);
    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      phone: '09120000000',
      passwordHash,
      isActive: true,
      deletedAt: null,
    });

    await expect(service.login('09120000000', 'wrong-password')).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('کاربر غیرفعال نباید بتواند وارد شود', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      phone: '09120000000',
      passwordHash: 'hash',
      isActive: false,
      deletedAt: null,
    });

    await expect(service.login('09120000000', 'any')).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('رفرش معتبر باید توکن قدیمی را باطل و یک جفت توکن جدید صادر کند (rotation)', async () => {
    jwtService.verifyAsync.mockResolvedValue({ sub: 'user-1', phone: '09120000000' });
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'rt-1',
      userId: 'user-1',
      tokenHash: 'hash',
      expiresAt: new Date(Date.now() + 1000 * 60 * 60),
      revokedAt: null,
    });
    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      phone: '09120000000',
      isActive: true,
      deletedAt: null,
    });

    const result = await service.refresh('old-refresh-token');

    expect(prisma.refreshToken.update).toHaveBeenCalledWith({
      where: { id: 'rt-1' },
      data: { revokedAt: expect.any(Date) },
    });
    expect(prisma.refreshToken.create).toHaveBeenCalled();
    expect(result.accessToken).toBe('signed-token');
  });

  it('استفاده مجدد از رفرش‌توکن باطل‌شده/ناموجود باید تمام نشست‌های کاربر را ابطال کند', async () => {
    jwtService.verifyAsync.mockResolvedValue({ sub: 'user-1', phone: '09120000000' });
    prisma.refreshToken.findUnique.mockResolvedValue(null);

    await expect(service.refresh('stolen-refresh-token')).rejects.toBeInstanceOf(UnauthorizedException);

    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
      where: { userId: 'user-1', revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
  });
});
