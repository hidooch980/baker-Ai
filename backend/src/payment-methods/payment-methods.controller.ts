import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PaymentMethodsService } from './payment-methods.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { PaymentMethodType } from '@prisma/client';

@ApiTags('payment-methods')
@Controller('payment-methods')
export class PaymentMethodsController {
  constructor(private readonly paymentMethodsService: PaymentMethodsService) {}

  @RequirePermissions('sales.view')
  @Get()
  findAll() {
    return this.paymentMethodsService.findAll();
  }

  @RequirePermissions('finance.manage')
  @Post()
  create(@Body() body: { name: string; type: PaymentMethodType }) {
    return this.paymentMethodsService.create(body.name, body.type);
  }
}
