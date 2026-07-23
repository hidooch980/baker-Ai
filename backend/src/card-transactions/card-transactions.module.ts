import { Module } from '@nestjs/common';
import { CardTransactionsService } from './card-transactions.service';
import { CardTransactionsController } from './card-transactions.controller';

@Module({
  providers: [CardTransactionsService],
  controllers: [CardTransactionsController],
  exports: [CardTransactionsService],
})
export class CardTransactionsModule {}
