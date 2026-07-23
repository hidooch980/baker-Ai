import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { AuditAction } from '@prisma/client';
import { GeneratePayrollDto } from './dto/generate-payroll.dto';

/** محاسبه حقوق و دستمزد با درنظر گرفتن اضافه‌کاری، مساعده‌ها و کسورات. */
const WORKING_DAYS_PER_MONTH = 30;
const WORKING_HOURS_PER_DAY = 8;

@Injectable()
export class PayrollService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async findAll() {
    return this.prisma.payroll.findMany({ include: { employee: true, payments: true }, orderBy: { periodStart: 'desc' }, take: 100 });
  }

  async findOne(id: string) {
    const payroll = await this.prisma.payroll.findUnique({ where: { id }, include: { employee: true, payments: true } });
    if (!payroll) throw new NotFoundException('فیش حقوق یافت نشد.');
    return payroll;
  }

  async generate(dto: GeneratePayrollDto, actorId?: string) {
    const employee = await this.prisma.employee.findFirst({ where: { id: dto.employeeId, deletedAt: null } });
    if (!employee) throw new BadRequestException('کارمند معتبر نیست.');

    const periodStart = new Date(dto.periodStart);
    const periodEnd = new Date(dto.periodEnd);
    const baseAmount = Number(employee.baseSalary ?? 0);

    const attendances = await this.prisma.attendance.findMany({
      where: { employeeId: dto.employeeId, date: { gte: periodStart, lte: periodEnd } },
    });
    const totalOvertimeHours = attendances.reduce((sum, a) => sum + a.overtimeHours, 0);
    const hourlyRate = baseAmount / (WORKING_DAYS_PER_MONTH * WORKING_HOURS_PER_DAY);
    const overtimePay = totalOvertimeHours * hourlyRate * 1.4;

    const advances = dto.advances ?? 0;
    const deductions = dto.deductions ?? 0;
    const netAmount = baseAmount + overtimePay - advances - deductions;

    const payroll = await this.prisma.payroll.create({
      data: {
        employeeId: dto.employeeId,
        periodStart,
        periodEnd,
        baseAmount,
        advances,
        deductions,
        netAmount,
      },
    });

    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'Payroll', entityId: payroll.id, newValue: payroll as any });
    return payroll;
  }

  async recordPayment(payrollId: string, amount: number, actorId?: string) {
    await this.findOne(payrollId);
    const payment = await this.prisma.payrollPayment.create({ data: { payrollId, amount } });
    await this.auditLogService.record({ userId: actorId, action: AuditAction.CREATE, entity: 'PayrollPayment', entityId: payment.id, newValue: payment as any });
    return payment;
  }
}
