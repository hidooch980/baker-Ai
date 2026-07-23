import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SalesService } from './sales.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('sales')
@Controller('sales')
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  @RequirePermissions('sales.view')
  @Get()
  findAll() {
    return this.salesService.findAll();
  }

  @RequirePermissions('sales.view')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.salesService.findOne(id);
  }

  @RequirePermissions('sales.create')
  @Post()
  create(@Body() dto: CreateSaleDto, @CurrentUser() actor: { id: string }) {
    return this.salesService.create(dto, actor?.id);
  }

  @RequirePermissions('sales.create')
  @Post(':id/void')
  void(@Param('id') id: string, @Body() body: { reason: string }, @CurrentUser() actor: { id: string }) {
    return this.salesService.void(id, body.reason, actor?.id);
  }
}
