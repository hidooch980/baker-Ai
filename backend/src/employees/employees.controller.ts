import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { EmployeesService } from './employees.service';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { UpdateEmployeeDto } from './dto/update-employee.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AttendanceStatus, ShiftType } from '@prisma/client';

@ApiTags('employees')
@Controller('employees')
export class EmployeesController {
  constructor(private readonly employeesService: EmployeesService) {}

  @RequirePermissions('employees.manage')
  @Get()
  findAll() {
    return this.employeesService.findAll();
  }

  @RequirePermissions('employees.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.employeesService.findOne(id);
  }

  @RequirePermissions('employees.manage')
  @Post()
  create(@Body() dto: CreateEmployeeDto, @CurrentUser() actor: { id: string }) {
    return this.employeesService.create(dto, actor?.id);
  }

  @RequirePermissions('employees.manage')
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateEmployeeDto, @CurrentUser() actor: { id: string }) {
    return this.employeesService.update(id, dto, actor?.id);
  }

  @RequirePermissions('employees.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.employeesService.remove(id, actor?.id);
  }

  @RequirePermissions('employees.manage')
  @Post(':id/shifts')
  assignShift(@Param('id') id: string, @Body() body: { shift: ShiftType; date: string }) {
    return this.employeesService.assignShift(id, body.shift, new Date(body.date));
  }

  @RequirePermissions('employees.manage')
  @Post(':id/attendance')
  recordAttendance(
    @Param('id') id: string,
    @Body() body: { date: string; status: AttendanceStatus; overtimeHours?: number; note?: string },
    @CurrentUser() actor: { id: string },
  ) {
    return this.employeesService.recordAttendance(id, new Date(body.date), body.status, body.overtimeHours, body.note, actor?.id);
  }

  @RequirePermissions('employees.manage')
  @Get(':id/attendance/summary')
  attendanceSummary(@Param('id') id: string, @Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.employeesService.attendanceSummary(id, new Date(startDate), new Date(endDate));
  }
}
