import { Module } from '@nestjs/common';
import { SalesService } from './sales.service';
import { SalesController } from './sales.controller';
import { DocumentSequenceModule } from '../document-sequence/document-sequence.module';

@Module({
  imports: [DocumentSequenceModule],
  providers: [SalesService],
  controllers: [SalesController],
  exports: [SalesService],
})
export class SalesModule {}
