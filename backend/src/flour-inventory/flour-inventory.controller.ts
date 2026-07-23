import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { FlourInventoryService } from './flour-inventory.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('flour-inventory')
@Controller('flour-inventory')
export class FlourInventoryController {
  constructor(private readonly flourInventoryService: FlourInventoryService) {}

  @RequirePermissions('production.manage')
  @Get()
  getCurrentStock() {
    return this.flourInventoryService.getCurrentStock();
  }

  @RequirePermissions('production.manage')
  @Post('stock')
  addStock(
    @Body() body: { bagCount?: number; bagWeightKg?: number; totalWeightKg: number; pricePerBag?: number; totalPrice?: number; supplierId?: string; invoiceNumber?: string },
    @CurrentUser() actor: { id: string },
  ) {
    return this.flourInventoryService.addStock(body, actor?.id);
  }

  @RequirePermissions('production.manage')
  @Post('min-stock')
  setMinStock(@Body() body: { minStockKg: number }) {
    return this.flourInventoryService.setMinStock(body.minStockKg);
  }

  @RequirePermissions('reports.view')
  @Get('reports/consumption')
  getConsumptionReport(@Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.flourInventoryService.getConsumptionReport(new Date(startDate), new Date(endDate));
  }
}
