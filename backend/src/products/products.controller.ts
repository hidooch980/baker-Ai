import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('products')
@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @RequirePermissions('sales.view')
  @Get()
  findAll() {
    return this.productsService.findAll();
  }

  @RequirePermissions('sales.view')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }

  @RequirePermissions('finance.manage')
  @Post()
  create(@Body() dto: CreateProductDto, @CurrentUser() actor: { id: string }) {
    return this.productsService.create(dto, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateProductDto, @CurrentUser() actor: { id: string }) {
    return this.productsService.update(id, dto, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.productsService.remove(id, actor?.id);
  }
}
