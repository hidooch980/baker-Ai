import { Module } from '@nestjs/common';
import { SyncService } from './sync.service';
import { SyncController } from './sync.controller';
import { SalesModule } from '../sales/sales.module';
import { ExpensesModule } from '../expenses/expenses.module';
import { EmployeesModule } from '../employees/employees.module';
import { ProductionModule } from '../production/production.module';

@Module({
  imports: [SalesModule, ExpensesModule, EmployeesModule, ProductionModule],
  providers: [SyncService],
  controllers: [SyncController],
  exports: [SyncService],
})
export class SyncModule {}
