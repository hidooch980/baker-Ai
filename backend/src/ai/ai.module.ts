import { Module } from '@nestjs/common';
import { AiService } from './ai.service';
import { AiController } from './ai.controller';
import { CustomersModule } from '../customers/customers.module';
import { FlourInventoryModule } from '../flour-inventory/flour-inventory.module';
import { FuelModule } from '../fuel/fuel.module';
import { ExpensesModule } from '../expenses/expenses.module';

@Module({
  imports: [CustomersModule, FlourInventoryModule, FuelModule, ExpensesModule],
  providers: [AiService],
  controllers: [AiController],
  exports: [AiService],
})
export class AiModule {}
