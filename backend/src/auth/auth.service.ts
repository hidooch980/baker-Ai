import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { createHash } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';

/** تبدیل رشته‌های مدت‌زمان مانند '15m'، '7d' به میلی‌ثانیه، برای محاسبه expiresAt رفرش‌توکن در دیتابیس. */
function parseDurationMs(duration: string | undefined): number {
  const fallbackMs = 15 * 60 * 1000;
  if (!duration) return fallbackMs;
  const match = /^(\d+)\s*(ms|s|m|h|d)?$/.exec(duration.trim());
  if (!match) return fallbackMs;
  const value = Number(match[1]);
  const unit = match[2] ?? 'ms';
  const unitToMs: Record<string, number> = { ms: 1, s: 1000, m: 60 * 1000, h: 60 * 60 * 1000, d: 24 * 60 * 60 * 1000 };
  return value * (unitToMs[unit] ?? 1);
}

/** رفرش‌توکن هرگز خام در دیتابیس ذخیره نمی‌شود؛ فقط هش آن ذخیره می‌شود تا در صورت نشت دیتابیس، توکن‌های خام لو نروند. */
function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * مدیریت ورود/خروج و توکن‌ها.
 *
 * رفرش‌توکن‌ها علاوه بر امضای JWT، هش‌شان در جدول RefreshToken ذخیره می‌شود تا:
 * - logout واقعاً توکن را باطل کند (نه فقط یک رکورد در audit log).
 * - هر refresh باعث چرخش (rotation) شود: توکن قبلی باطل و یک جفت توکن جدید صادر می‌شود.
 * - استفاده مجدد از یک رفرش‌توکن باطل‌شده/سرقت‌شده شناسایی و تمام نشست‌های کاربر بسته شود.
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly auditLogService: AuditLogService,
  ) {}

  private async signTokens(userId: string, phone: string) {
    const payload = { sub: userId, phone };
    const accessToken = await this.jwtService.signAsync(payload, {
      secret: this.config.get<string>('jwt.accessSecret'),
      expiresIn: this.config.get<string>('jwt.accessExpiresIn'),
    });
    const refreshExpiresIn = this.config.get<string>('jwt.refreshExpiresIn');
    const refreshToken = await this.jwtService.signAsync(payload, {
      secret: this.config.get<string>('jwt.refreshSecret'),
      expiresIn: refreshExpiresIn,
    });

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: hashToken(refreshToken),
        expiresAt: new Date(Date.now() + parseDurationMs(refreshExpiresIn)),
      },
    });

    return { accessToken, refreshToken };
  }

  /** ابطال تمام رفرش‌توکن‌های فعال یک کاربر؛ برای logout واقعی یا مقابله با نشت/استفاده مجدد توکن. */
  private async revokeAllRefreshTokens(userId: string) {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async login(phone: string, password: string, ipAddress?: string, device?: string) {
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user || user.deletedAt || !user.isActive) {
      throw new UnauthorizedException('شماره تلفن یا رمز عبور اشتباه است.');
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatches) {
      throw new UnauthorizedException('شماره تلفن یا رمز عبور اشتباه است.');
    }

    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    await this.auditLogService.record({
      userId: user.id,
      action: AuditAction.LOGIN,
      entity: 'User',
      entityId: user.id,
      ipAddress,
      device,
    });

    const tokens = await this.signTokens(user.id, user.phone);
    return { ...tokens, user: { id: user.id, fullName: user.fullName, phone: user.phone } };
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string; phone: string };
    try {
      payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: this.config.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('رمز عبور نامعتبر یا منقضی شده است.');
    }

    const tokenHash = hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });

    if (!stored || stored.revokedAt || stored.expiresAt.getTime() < Date.now()) {
      // توکن در دیتابیس یافت نشد یا قبلاً باطل/منقضی شده؛ یعنی احتمال استفاده مجدد از توکن سرقت‌شده یا چرخش‌یافته است.
      // برای احتیاط، تمام نشست‌های فعال این کاربر بسته می‌شود تا کاربر واقعی مجدداً وارد شود.
      await this.revokeAllRefreshTokens(payload.sub);
      throw new UnauthorizedException('رمز عبور نامعتبر یا منقضی شده است.');
    }

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.deletedAt || !user.isActive) {
      throw new UnauthorizedException('کاربر یافت نشد.');
    }

    // چرخش توکن: توکن قبلی بی‌درنگ باطل می‌شود تا فقط یک‌بار قابل استفاده باشد.
    await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });

    return this.signTokens(user.id, user.phone);
  }

  async logout(userId: string, ipAddress?: string, device?: string) {
    await this.revokeAllRefreshTokens(userId);
    await this.auditLogService.record({
      userId,
      action: AuditAction.LOGOUT,
      entity: 'User',
      entityId: userId,
      ipAddress,
      device,
    });
    return { success: true };
  }
}
