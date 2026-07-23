import { Module } from '@nestjs/common';
import { DailyClosingService } from './daily-closing.service';
import { DailyClosingController } from './daily-closing.controller';

@Module({
  providers: [DailyClosingService],
  controllers: [DailyClosingController],
  exports: [DailyClosingService],
})
export class DailyClosingModule {}
