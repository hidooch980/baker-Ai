import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ProductionService } from './production.service';
import { CreateProductionDto } from './dto/create-production.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('production')
@Controller('production')
export class ProductionController {
  constructor(private readonly productionService: ProductionService) {}

  @RequirePermissions('production.manage')
  @Get()
  findAll() {
    return this.productionService.findAll();
  }

  @RequirePermissions('production.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.productionService.findOne(id);
  }

  @RequirePermissions('production.manage')
  @Post()
  create(@Body() dto: CreateProductionDto, @CurrentUser() actor: { id: string }) {
    return this.productionService.create(dto, actor?.id);
  }

  @RequirePermissions('reports.view')
  @Get('reports/production-vs-sales')
  report(@Query('productId') productId: string, @Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.productionService.productionVsSalesReport(productId, new Date(startDate), new Date(endDate));
  }
}
