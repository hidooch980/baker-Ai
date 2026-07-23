import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';

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
    const refreshToken = await this.jwtService.signAsync(payload, {
      secret: this.config.get<string>('jwt.refreshSecret'),
      expiresIn: this.config.get<string>('jwt.refreshExpiresIn'),
    });
    return { accessToken, refreshToken };
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

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.deletedAt || !user.isActive) {
      throw new UnauthorizedException('کاربر یافت نشد.');
    }

    return this.signTokens(user.id, user.phone);
  }

  async logout(userId: string, ipAddress?: string, device?: string) {
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
