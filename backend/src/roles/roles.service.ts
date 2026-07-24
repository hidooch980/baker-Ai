import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';

@Injectable()
export class RolesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  findAll() {
    return this.prisma.role.findMany({ include: { rolePermissions: { include: { permission: true } } } });
  }

  async findOne(id: string) {
    const role = await this.prisma.role.findUnique({
      where: { id },
      include: { rolePermissions: { include: { permission: true } } },
    });
    if (!role) throw new NotFoundException('نقش یافت نشد.');
    return role;
  }

  async create(name: string, description: string | undefined, actorId?: string) {
    const role = await this.prisma.role.create({ data: { name, description } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Role', entityId: role.id, newValue: role as any });
    return role;
  }

  /**
   * جایگزینی کامل دسترسی‌های یک نقش. حذف و ایجاد ردیف‌های rolePermission در یک تراکنش دیتابیسی
   * انجام می‌شود تا اگر سرور بین این دو عملیات کرش کند، نقش به‌طور موقت با صفر دسترسی باقی نماند
   * (که می‌توانست باعث قفل‌شدن ناخواسته دسترسی کاربران دارای آن نقش شود).
   */
  async setPermissions(roleId: string, permissionIds: string[], actorId?: string) {
    const before = await this.findOne(roleId);
    await this.prisma.$transaction([
      this.prisma.rolePermission.deleteMany({ where: { roleId } }),
      this.prisma.rolePermission.createMany({ data: permissionIds.map((permissionId) => ({ roleId, permissionId })) }),
    ]);
    const after = await this.findOne(roleId);
    await this.auditLogService.record({
      userId: actorId,
      action: AuditAction.PERMISSION_CHANGE,
      entity: 'Role',
      entityId: roleId,
      oldValue: before as any,
      newValue: after as any,
    });
    return after;
  }
}
