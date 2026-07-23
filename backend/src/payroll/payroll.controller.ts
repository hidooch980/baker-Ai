import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PayrollService } from './payroll.service';
import { GeneratePayrollDto } from './dto/generate-payroll.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('payroll')
@Controller('payroll')
export class PayrollController {
  constructor(private readonly payrollService: PayrollService) {}

  @RequirePermissions('employees.manage')
  @Get()
  findAll() {
    return this.payrollService.findAll();
  }

  @RequirePermissions('employees.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.payrollService.findOne(id);
  }

  @RequirePermissions('employees.manage')
  @Post()
  generate(@Body() dto: GeneratePayrollDto, @CurrentUser() actor: { id: string }) {
    return this.payrollService.generate(dto, actor?.id);
  }

  @RequirePermissions('employees.manage')
  @Post(':id/payments')
  recordPayment(@Param('id') id: string, @Body() body: { amount: number }, @CurrentUser() actor: { id: string }) {
    return this.payrollService.recordPayment(id, body.amount, actor?.id);
  }
}
