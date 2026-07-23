import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../audit-log/audit-log.service';
import { BackupStatus, BackupType, AuditAction } from '@prisma/client';

@Injectable()
export class BackupService {
  private readonly logger = new Logger(BackupService.name);
  private readonly backupDir: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly auditLogService: AuditLogService,
  ) {
    this.backupDir = this.configService.get<string>('backup.dir') ?? path.join(process.cwd(), 'backups');
    if (!fs.existsSync(this.backupDir)) {
      fs.mkdirSync(this.backupDir, { recursive: true });
    }
  }

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async handleScheduledBackup() {
    this.logger.log('شروع پشتیبان‌گیری زمان‌بندی‌شده روزانه');
    await this.runBackup(BackupType.DAILY);
  }

  async runBackup(type: BackupType = BackupType.MANUAL, actorId?: string, note?: string) {
    const startedAt = new Date();
    const backup = await this.prisma.backup.create({
      data: { type, status: BackupStatus.PENDING, startedAt, note: note ?? null },
    });

    const timestamp = startedAt.toISOString().replace(/[:.]/g, '-');
    const fileName = `bakery-backup-${type.toLowerCase()}-${timestamp}.sql`;
    const filePath = path.join(this.backupDir, fileName);
    const databaseUrl = this.configService.get<string>('databaseUrl');

    try {
      await this.runPgDump(databaseUrl, filePath);
      const stats = fs.statSync(filePath);
      const finishedAt = new Date();
      const updated = await this.prisma.backup.update({
        where: { id: backup.id },
        data: {
          status: BackupStatus.SUCCESS,
          fileUrl: filePath,
          sizeBytes: stats.size,
          finishedAt,
        },
      });

      if (actorId) {
        await this.auditLogService.record({
          userId: actorId,
          action: AuditAction.OTHER,
          entity: 'Backup',
          entityId: backup.id,
          reason: 'اجرای پشتیبان‌گیری دستی',
        });
      }

      await this.cleanupOldBackups();
      return updated;
    } catch (error) {
      const message = (error as Error).message ?? 'خطای نامشخص در پشتیبان‌گیری';
      this.logger.error(`پشتیبان‌گیری با خطا مواجه شد: ${message}`);
      return this.prisma.backup.update({
        where: { id: backup.id },
        data: {
          status: BackupStatus.FAILED,
          note: message.slice(0, 500),
          finishedAt: new Date(),
        },
      });
    }
  }

  private runPgDump(databaseUrl: string | undefined, filePath: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!databaseUrl) {
        reject(new Error('DATABASE_URL تنظیم نشده است.'));
        return;
      }
      const dump = spawn('pg_dump', ['--no-owner', '--no-privileges', '-f', filePath, databaseUrl]);
      let stderr = '';
      dump.stderr.on('data', (chunk) => {
        stderr += chunk.toString();
      });
      dump.on('error', (err) => reject(err));
      dump.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(stderr || `pg_dump با کد خروج ${code} پایان یافت.`));
        }
      });
    });
  }

  private async cleanupOldBackups() {
    const retentionDays = Number(this.configService.get<number>('backup.retentionDays') ?? 14);
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - retentionDays);

    const oldBackups = await this.prisma.backup.findMany({
      where: { status: BackupStatus.SUCCESS, startedAt: { lt: cutoff } },
    });

    for (const old of oldBackups) {
      if (old.fileUrl && fs.existsSync(old.fileUrl)) {
        try {
          fs.unlinkSync(old.fileUrl);
        } catch (err) {
          this.logger.warn(`حذف فایل پشتیبان قدیمی ناموفق بود: ${(err as Error).message}`);
        }
      }
    }
  }

  async findAll() {
    return this.prisma.backup.findMany({ orderBy: { startedAt: 'desc' }, take: 50 });
  }
}
