import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DoughService } from './dough.service';
import { CreateDoughBatchDto } from './dto/create-dough-batch.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('dough')
@Controller('dough-batches')
export class DoughController {
  constructor(private readonly doughService: DoughService) {}

  @RequirePermissions('dough.manage')
  @Get()
  findAll() {
    return this.doughService.findAll();
  }

  @RequirePermissions('dough.manage')
  @Post()
  create(@Body() dto: CreateDoughBatchDto, @CurrentUser() actor: { id: string }) {
    return this.doughService.create(dto, actor?.id);
  }
}
