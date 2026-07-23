import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SuppliersService } from './suppliers.service';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('suppliers')
@Controller('suppliers')
export class SuppliersController {
  constructor(private readonly suppliersService: SuppliersService) {}

  @RequirePermissions('finance.manage')
  @Get()
  findAll() {
    return this.suppliersService.findAll();
  }

  @RequirePermissions('finance.manage')
  @Get('debts/report')
  debtReport() {
    return this.suppliersService.debtReport();
  }

  @RequirePermissions('finance.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.suppliersService.findOne(id);
  }

  @RequirePermissions('finance.manage')
  @Post()
  create(@Body() dto: CreateSupplierDto, @CurrentUser() actor: { id: string }) {
    return this.suppliersService.create(dto, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateSupplierDto, @CurrentUser() actor: { id: string }) {
    return this.suppliersService.update(id, dto, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Post(':id/payments')
  recordPayment(@Param('id') id: string, @Body() body: { amount: number; paymentMethodId: string }, @CurrentUser() actor: { id: string }) {
    return this.suppliersService.recordPayment(id, body.amount, body.paymentMethodId, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.suppliersService.remove(id, actor?.id);
  }
}
