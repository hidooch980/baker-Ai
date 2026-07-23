import { Controller, Get, Query } from '@nestjs/common';
import { AuditLogService } from './audit-log.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('audit-log')
@Controller('audit-log')
export class AuditLogController {
  constructor(private readonly auditLogService: AuditLogService) {}

  @RequirePermissions('roles.manage')
  @Get()
  findByEntity(@Query('entity') entity: string, @Query('entityId') entityId: string) {
    return this.auditLogService.findByEntity(entity, entityId);
  }

  @Get('my-sessions')
  mySessions(@CurrentUser() actor: { id: string }) {
    return this.auditLogService.findLoginHistory(actor.id);
  }
}
