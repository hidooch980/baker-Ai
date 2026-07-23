import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  private select() {
    return {
      id: true,
      fullName: true,
      phone: true,
      email: true,
      isActive: true,
      lastLoginAt: true,
      createdAt: true,
      userRoles: { include: { role: true } },
    };
  }

  async findAll() {
    return this.prisma.user.findMany({ where: { deletedAt: null }, select: this.select() });
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findFirst({ where: { id, deletedAt: null }, select: this.select() });
    if (!user) throw new NotFoundException('کاربر یافت نشد.');
    return user;
  }

  async create(dto: CreateUserDto, actorId?: string) {
    const existing = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    if (existing) throw new ConflictException('این شماره تلفن قبلاً ثبت شده است.');

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        fullName: dto.fullName,
        phone: dto.phone,
        email: dto.email,
        passwordHash,
        userRoles: dto.roleIds
          ? { create: dto.roleIds.map((roleId) => ({ roleId })) }
          : undefined,
      },
      select: this.select(),
    });

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.CREATE,
      entity: 'User',
      entityId: user.id,
      newValue: user as any,
    });

    return user;
  }

  async update(id: string, dto: UpdateUserDto, actorId?: string) {
    const before = await this.findOne(id);

    const data: Record<string, unknown> = {};
    if (dto.fullName) data.fullName = dto.fullName;
    if (dto.email) data.email = dto.email;
    if (dto.password) data.passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.update({ where: { id }, data, select: this.select() });

    if (dto.roleIds) {
      await this.prisma.userRole.deleteMany({ where: { userId: id } });
      await this.prisma.userRole.createMany({
        data: dto.roleIds.map((roleId) => ({ userId: id, roleId })),
      });
    }

    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.UPDATE,
      entity: 'User',
      entityId: id,
      oldValue: before as any,
      newValue: user as any,
    });

    return this.findOne(id);
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.user.update({ where: { id }, data: { deletedAt: new Date(), isActive: false } });
    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.DELETE,
      entity: 'User',
      entityId: id,
    });
    return { success: true };
  }
}
