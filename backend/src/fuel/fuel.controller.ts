import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { FuelService } from './fuel.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { FuelType } from '@prisma/client';

@ApiTags('fuel')
@Controller('fuel-tanks')
export class FuelController {
  constructor(private readonly fuelService: FuelService) {}

  @RequirePermissions('production.manage')
  @Get()
  findAll() {
    return this.fuelService.findAllTanks();
  }

  @RequirePermissions('production.manage')
  @Post()
  createTank(@Body() body: { fuelType: FuelType; capacityLiters: number }) {
    return this.fuelService.createTank(body.fuelType, body.capacityLiters);
  }

  @RequirePermissions('production.manage')
  @Post(':id/add')
  addFuel(@Param('id') id: string, @Body() body: { liters: number; pricePerLiter?: number }, @CurrentUser() actor: { id: string }) {
    return this.fuelService.addFuel(id, body.liters, body.pricePerLiter, actor?.id);
  }

  @RequirePermissions('production.manage')
  @Post(':id/consume')
  consumeFuel(@Param('id') id: string, @Body() body: { liters: number; note?: string }, @CurrentUser() actor: { id: string }) {
    return this.fuelService.consumeFuel(id, body.liters, body.note, actor?.id);
  }

  @RequirePermissions('reports.view')
  @Get(':id/reports/consumption')
  getConsumptionReport(@Param('id') id: string, @Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.fuelService.getConsumptionReport(id, new Date(startDate), new Date(endDate));
  }
}
