import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('expenses')
@Controller('expenses')
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @RequirePermissions('finance.manage')
  @Get()
  findAll() {
    return this.expensesService.findAll();
  }

  @RequirePermissions('reports.view')
  @Get('reports/summary')
  report(@Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.expensesService.report(new Date(startDate), new Date(endDate));
  }

  @RequirePermissions('finance.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.expensesService.findOne(id);
  }

  @RequirePermissions('finance.manage')
  @Post()
  create(@Body() dto: CreateExpenseDto, @CurrentUser() actor: { id: string }) {
    return this.expensesService.create(dto, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.expensesService.remove(id, actor?.id);
  }
}
