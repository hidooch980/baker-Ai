import { Module, OnModuleInit } from '@nestjs/common';
import { PaymentMethodsService } from './payment-methods.service';
import { PaymentMethodsController } from './payment-methods.controller';

@Module({
  providers: [PaymentMethodsService],
  controllers: [PaymentMethodsController],
  exports: [PaymentMethodsService],
})
export class PaymentMethodsModule implements OnModuleInit {
  constructor(private readonly paymentMethodsService: PaymentMethodsService) {}

  async onModuleInit() {
    await this.paymentMethodsService.ensureDefaults();
  }
}
