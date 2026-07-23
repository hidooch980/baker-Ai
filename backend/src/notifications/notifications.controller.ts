import { Controller, Get, Param, Patch, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('notifications')
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  findAll(@CurrentUser() actor: { id: string }, @Query('onlyUnread') onlyUnread?: string) {
    return this.notificationsService.findForUser(actor.id, onlyUnread === 'true');
  }

  @Get('unread-count')
  unreadCount(@CurrentUser() actor: { id: string }) {
    return this.notificationsService.unreadCount(actor.id);
  }

  @Patch('read-all')
  markAllRead(@CurrentUser() actor: { id: string }) {
    return this.notificationsService.markAllRead(actor.id);
  }

  @Patch(':id/read')
  markRead(@Param('id') id: string) {
    return this.notificationsService.markRead(id);
  }
}
