import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DailyClosingService } from './daily-closing.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('daily-closing')
@Controller('daily-closing')
export class DailyClosingController {
  constructor(private readonly dailyClosingService: DailyClosingService) {}

  @RequirePermissions('reports.view')
  @Get()
  findAll() {
    return this.dailyClosingService.findAll();
  }

  @RequirePermissions('reports.view')
  @Get('preview')
  preview(@Query('date') date: string) {
    return this.dailyClosingService.preview(new Date(date));
  }

  @RequirePermissions('reports.view')
  @Get('by-date')
  findByDate(@Query('date') date: string) {
    return this.dailyClosingService.findByDate(new Date(date));
  }

  @RequirePermissions('finance.manage')
  @Post('close')
  closeDay(@Body() body: { date: string }, @CurrentUser() actor: { id: string }) {
    return this.dailyClosingService.closeDay(new Date(body.date), actor?.id);
  }

  @RequirePermissions('finance.manage')
  @Post('reopen')
  reopen(@Body() body: { date: string; reason: string }, @CurrentUser() actor: { id: string }) {
    return this.dailyClosingService.reopen(new Date(body.date), body.reason, actor?.id);
  }
}
