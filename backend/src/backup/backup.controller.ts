import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { BackupService } from './backup.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { BackupType } from '@prisma/client';

@ApiTags('backup')
@Controller('backups')
export class BackupController {
  constructor(private readonly backupService: BackupService) {}

  @RequirePermissions('roles.manage')
  @Get()
  findAll() {
    return this.backupService.findAll();
  }

  @RequirePermissions('roles.manage')
  @Post('manual')
  runManual(@Body() body: { note?: string }, @CurrentUser() actor: { id: string }) {
    return this.backupService.runBackup(BackupType.MANUAL, actor?.id, body?.note);
  }
}
