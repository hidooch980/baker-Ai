import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('customers')
@Controller('customers')
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @RequirePermissions('sales.view')
  @Get()
  findAll() {
    return this.customersService.findAll();
  }

  @RequirePermissions('sales.view')
  @Get('debts/report')
  debtReport() {
    return this.customersService.debtReport();
  }

  @RequirePermissions('sales.view')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.customersService.findOne(id);
  }

  @RequirePermissions('sales.create')
  @Post()
  create(@Body() dto: CreateCustomerDto, @CurrentUser() actor: { id: string }) {
    return this.customersService.create(dto, actor?.id);
  }

  @RequirePermissions('sales.create')
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateCustomerDto, @CurrentUser() actor: { id: string }) {
    return this.customersService.update(id, dto, actor?.id);
  }

  @RequirePermissions('sales.create')
  @Post(':id/transactions')
  addTransaction(
    @Param('id') id: string,
    @Body() body: { type: 'PAYMENT' | 'DEBT' | 'SETTLEMENT'; amount: number; note?: string; dueDate?: string },
    @CurrentUser() actor: { id: string },
  ) {
    return this.customersService.addTransaction(id, body.type, body.amount, body.note, body.dueDate ? new Date(body.dueDate) : undefined, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.customersService.remove(id, actor?.id);
  }
}
