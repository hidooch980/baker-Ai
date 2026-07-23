import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import configuration from './config/configuration';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { RolesModule } from './roles/roles.module';
import { PermissionsModule } from './permissions/permissions.module';
import { AuditLogModule } from './audit-log/audit-log.module';
import { HealthModule } from './health/health.module';
import { DocumentSequenceModule } from './document-sequence/document-sequence.module';
import { ProductsModule } from './products/products.module';
import { PaymentMethodsModule } from './payment-methods/payment-methods.module';
import { CardTransactionsModule } from './card-transactions/card-transactions.module';
import { SalesModule } from './sales/sales.module';
import { CashBoxModule } from './cash-box/cash-box.module';
import { ProductionModule } from './production/production.module';
import { DoughModule } from './dough/dough.module';
import { FlourInventoryModule } from './flour-inventory/flour-inventory.module';
import { InventoryModule } from './inventory/inventory.module';
import { FuelModule } from './fuel/fuel.module';
import { CustomersModule } from './customers/customers.module';
import { SuppliersModule } from './suppliers/suppliers.module';
import { PurchasesModule } from './purchases/purchases.module';
import { ExpensesModule } from './expenses/expenses.module';
import { EmployeesModule } from './employees/employees.module';
import { PayrollModule } from './payroll/payroll.module';
import { DailyClosingModule } from './daily-closing/daily-closing.module';
import { ReportsModule } from './reports/reports.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.THROTTLE_TTL ?? 60) * 1000,
        limit: Number(process.env.THROTTLE_LIMIT ?? 100),
      },
    ]),
    PrismaModule,
    AuditLogModule,
    AuthModule,
    UsersModule,
    RolesModule,
    PermissionsModule,
    HealthModule,
    DocumentSequenceModule,
    ProductsModule,
    PaymentMethodsModule,
    CardTransactionsModule,
    SalesModule,
    CashBoxModule,
    ProductionModule,
    DoughModule,
    FlourInventoryModule,
    InventoryModule,
    FuelModule,
    CustomersModule,
    SuppliersModule,
    PurchasesModule,
    ExpensesModule,
    EmployeesModule,
    PayrollModule,
    DailyClosingModule,
    ReportsModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
