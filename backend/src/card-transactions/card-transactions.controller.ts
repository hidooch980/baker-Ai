import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { CardTransactionsService } from './card-transactions.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('card-transactions')
@Controller('card-transactions')
export class CardTransactionsController {
  constructor(private readonly cardTransactionsService: CardTransactionsService) {}

  @RequirePermissions('finance.manage')
  @Post()
  create(
    @Body() body: { amount: number; occurredAt: string; terminalId?: string; traceNumber?: string; refNumber?: string },
    @CurrentUser() actor: { id: string },
  ) {
    return this.cardTransactionsService.create({
      ...body,
      occurredAt: new Date(body.occurredAt),
      createdById: actor?.id,
    });
  }

  @RequirePermissions('finance.manage')
  @Get('reconcile')
  reconcile(@Query('date') date: string) {
    return this.cardTransactionsService.reconcileForDate(new Date(date));
  }
}
