import { Module } from '@nestjs/common';
import { FlourInventoryService } from './flour-inventory.service';
import { FlourInventoryController } from './flour-inventory.controller';

@Module({
  providers: [FlourInventoryService],
  controllers: [FlourInventoryController],
  exports: [FlourInventoryService],
})
export class FlourInventoryModule {}
