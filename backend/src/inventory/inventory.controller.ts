import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { InventoryService } from './inventory.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { InventoryTxType } from '@prisma/client';

@ApiTags('inventory')
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @RequirePermissions('production.manage')
  @Get()
  findAll() {
    return this.inventoryService.findAll();
  }

  @RequirePermissions('production.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.inventoryService.findOne(id);
  }

  @RequirePermissions('production.manage')
  @Post()
  create(@Body() body: { name: string; unit: string; minStock?: number; price?: number; supplierId?: string }, @CurrentUser() actor: { id: string }) {
    return this.inventoryService.create(body, actor?.id);
  }

  @RequirePermissions('production.manage')
  @Post(':id/adjust')
  adjust(@Param('id') id: string, @Body() body: { type: InventoryTxType; quantity: number; note?: string }, @CurrentUser() actor: { id: string }) {
    return this.inventoryService.adjustStock(id, body.type, body.quantity, body.note, actor?.id);
  }

  @RequirePermissions('production.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.inventoryService.remove(id, actor?.id);
  }
}
