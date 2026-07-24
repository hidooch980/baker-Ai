import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async findForUser(userId: string, onlyUnread = false) {
    return this.prisma.notification.findMany({
      where: {
        OR: [{ userId }, { userId: null }],
        ...(onlyUnread ? { isRead: false } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async unreadCount(userId: string) {
    return this.prisma.notification.count({
      where: { OR: [{ userId }, { userId: null }], isRead: false },
    });
  }

  /**
   * رفع باگ دسترسی (IDOR): پیش‌تر این متد بدون بررسی مالکیت، هر شناسه اعلانی را می‌پذیرفت
   * و هر کاربر لاگین‌شده می‌توانست اعلان‌های خصوصی کاربران دیگر را با حدس/شمارش شناسه، خوانده‌شده علامت بزند.
   * اکنون فقط صاحب اعلان یا اعلان‌های عمومی (userId=null) قابل علامت‌گذاری توسط کاربر هستند.
   */
  async markRead(id: string, userId: string) {
    const notification = await this.prisma.notification.findUnique({ where: { id } });
    if (!notification) throw new NotFoundException('اعلان یافت نشد.');
    if (notification.userId !== null && notification.userId !== userId) {
      throw new ForbiddenException('اجازه دسترسی به این اعلان را ندارید.');
    }
    return this.prisma.notification.update({ where: { id }, data: { isRead: true } });
  }

  async markAllRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { OR: [{ userId }, { userId: null }], isRead: false },
      data: { isRead: true },
    });
  }
}
