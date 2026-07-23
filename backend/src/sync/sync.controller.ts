import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SyncService } from './sync.service';
import { SyncPushDto } from './dto/sync-push.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('sync')
@Controller('sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  push(@Body() dto: SyncPushDto, @CurrentUser() actor: { id: string }) {
    return this.syncService.push(dto.clientId, dto.operations, actor?.id);
  }

  @Get('pull')
  pull(@Query('since') since?: string) {
    return this.syncService.pull(since ? new Date(since) : null);
  }

  @Get('queue-status')
  queueStatus(@Query('clientId') clientId: string) {
    return this.syncService.queueStatus(clientId);
  }
}
