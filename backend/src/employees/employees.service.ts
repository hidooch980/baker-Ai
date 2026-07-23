import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction, AttendanceStatus, ShiftType } from '@prisma/client';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { UpdateEmployeeDto } from './dto/update-employee.dto';

/** مدیریت کارکنان، شیفت‌ها و حضور/عدم حضور. */
@Injectable()
export class EmployeesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  findAll() {
    return this.prisma.employee.findMany({ where: { deletedAt: null }, orderBy: { fullName: 'asc' } });
  }

  async findOne(id: string) {
    const employee = await this.prisma.employee.findFirst({
      where: { id, deletedAt: null },
      include: { shifts: { orderBy: { date: 'desc' }, take: 30 }, attendances: { orderBy: { date: 'desc' }, take: 30 } },
    });
    if (!employee) throw new NotFoundException('کارمند یافت نشد.');
    return employee;
  }

  async create(dto: CreateEmployeeDto, actorId?: string) {
    if (dto.userId) {
      const existing = await this.prisma.employee.findUnique({ where: { userId: dto.userId } });
      if (existing) throw new ConflictException('این کاربر قبلاً به یک کارمند متصل است.');
    }
    const employee = await this.prisma.employee.create({ data: dto });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Employee', entityId: employee.id, newValue: employee as any });
    return employee;
  }

  async update(id: string, dto: UpdateEmployeeDto, actorId?: string) {
    await this.findOne(id);
    const employee = await this.prisma.employee.update({ where: { id }, data: dto });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.UPDATE, entity: 'Employee', entityId: id, newValue: employee as any });
    return employee;
  }

  async remove(id: string, actorId?: string) {
    await this.findOne(id);
    await this.prisma.employee.update({ where: { id }, data: { isActive: false, deletedAt: new Date() } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.DELETE, entity: 'Employee', entityId: id });
    return { success: true };
  }

  async assignShift(employeeId: string, shift: ShiftType, date: Date) {
    await this.findOne(employeeId);
    return this.prisma.employeeShift.create({ data: { employeeId, shift, date } });
  }

  async recordAttendance(employeeId: string, date: Date, status: AttendanceStatus, overtimeHours: number | undefined, note: string | undefined, actorId?: string) {
    await this.findOne(employeeId);
    const attendance = await this.prisma.attendance.create({
      data: { employeeId, date, status, overtimeHours: overtimeHours ?? 0, note },
    });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Attendance', entityId: attendance.id, newValue: attendance as any });
    return attendance;
  }

  async attendanceSummary(employeeId: string, startDate: Date, endDate: Date) {
    const records = await this.prisma.attendance.findMany({ where: { employeeId, date: { gte: startDate, lte: endDate } } });
    const presentDays = records.filter((r) => r.status === 'PRESENT' || r.status === 'OVERTIME' || r.status === 'HALF_DAY').length;
    const absentDays = records.filter((r) => r.status === 'ABSENT').length;
    const leaveDays = records.filter((r) => r.status === 'LEAVE').length;
    const totalOvertimeHours = records.reduce((sum, r) => sum + r.overtimeHours, 0);
    return { presentDays, absentDays, leaveDays, totalOvertimeHours };
  }
}
