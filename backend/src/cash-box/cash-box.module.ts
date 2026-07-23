import { Module } from '@nestjs/common';
import { CashBoxService } from './cash-box.service';
import { CashBoxController } from './cash-box.controller';

@Module({
  providers: [CashBoxService],
  controllers: [CashBoxController],
  exports: [CashBoxService],
})
export class CashBoxModule {}
