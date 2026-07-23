import { Module } from '@nestjs/common';
import { DoughService } from './dough.service';
import { DoughController } from './dough.controller';

@Module({
  providers: [DoughService],
  controllers: [DoughController],
  exports: [DoughService],
})
export class DoughModule {}
