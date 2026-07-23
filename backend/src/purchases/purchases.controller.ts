import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PurchasesService } from './purchases.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('purchases')
@Controller('purchases')
export class PurchasesController {
  constructor(private readonly purchasesService: PurchasesService) {}

  @RequirePermissions('finance.manage')
  @Get()
  findAll() {
    return this.purchasesService.findAll();
  }

  @RequirePermissions('finance.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.purchasesService.findOne(id);
  }

  @RequirePermissions('finance.manage')
  @Post()
  create(@Body() dto: CreatePurchaseDto, @CurrentUser() actor: { id: string }) {
    return this.purchasesService.create(dto, actor?.id);
  }
}
