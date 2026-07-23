import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { CashBoxService } from './cash-box.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('cash-box')
@Controller('cash-box')
export class CashBoxController {
  constructor(private readonly cashBoxService: CashBoxService) {}

  @RequirePermissions('finance.manage')
  @Get('open')
  getOpen() {
    return this.cashBoxService.getOpenCashBox();
  }

  @RequirePermissions('finance.manage')
  @Post('open')
  openDay(@Body() body: { date: string; openingBalance: number }, @CurrentUser() actor: { id: string }) {
    return this.cashBoxService.openDay(new Date(body.date), body.openingBalance, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Post(':id/transactions')
  addTransaction(
    @Param('id') id: string,
    @Body() body: { type: string; amount: number; note?: string },
    @CurrentUser() actor: { id: string },
  ) {
    return this.cashBoxService.addTransaction(id, body.type, body.amount, body.note, actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Post(':id/close')
  closeDay(@Param('id') id: string, @Body() body: { actualClosingBalance: number }, @CurrentUser() actor: { id: string }) {
    return this.cashBoxService.closeDay(id, body.actualClosingBalance, actor?.id);
  }
}
