import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { CustomersService } from '../customers/customers.service';
import { FlourInventoryService } from '../flour-inventory/flour-inventory.service';
import { FuelService } from '../fuel/fuel.service';
import { ExpensesService } from '../expenses/expenses.service';
import { AIRole, PaymentMethodType, SaleStatus } from '@prisma/client';

type GroundedContext = Record<string, unknown>;

/**
 * دستیار هوش مند (Bakery AI): به سوالات فارسی درباره وضعیت نانوایی فقط بر اساس داده‌های واقعی داخل سیستم پاسخ می‌دهد (بدون توهم/حدس).
 * اگر کلید API هوش مصنوعی (AI_API_KEY) تنظیم شده باشد، مدل زبانی برای روان‌سازی متن فراخوانی می‌شود؛
 * در صورت عدم وجود کلید، پاسخ ترکیبی ساده از همان داده‌های مستندساز بازگردانده می‌شود.
 */
@Injectable()
export class AiService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly customersService: CustomersService,
    private readonly flourInventoryService: FlourInventoryService,
    private readonly fuelService: FuelService,
    private readonly expensesService: ExpensesService,
  ) {}

  async listConversations(userId?: string) {
    return this.prisma.aIConversation.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 50 });
  }

  async getConversation(id: string) {
    const conversation = await this.prisma.aIConversation.findUnique({
      where: { id },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!conversation) throw new NotFoundException('گفتگو یافت نشد.');
    return conversation;
  }

  async ask(question: string, userId?: string, conversationId?: string) {
    const conversation = conversationId
      ? await this.prisma.aIConversation.findUnique({ where: { id: conversationId } })
      : await this.prisma.aIConversation.create({ data: { userId: userId ?? null, title: question.slice(0, 60) } });

    if (!conversation) throw new NotFoundException('گفتگو یافت نشد.');

    await this.prisma.aIMessage.create({
      data: { conversationId: conversation.id, role: AIRole.USER, content: question },
    });

    const context = await this.gatherContext(question);
    const answer = await this.generateAnswer(question, context);

    await this.prisma.aIMessage.create({
      data: { conversationId: conversation.id, role: AIRole.ASSISTANT, content: answer, dataContext: context as any },
    });

    return { conversationId: conversation.id, answer, context };
  }

  /** تشخیص موضوع سوال و واکشی داده‌های مرتبط از داده‌های واقعی. */
  private async gatherContext(question: string): Promise<GroundedContext> {
    const context: GroundedContext = {};
    const q = question.toLowerCase();

    const mentionsSales = /فروش|درامد|فروخت/.test(q);
    const mentionsDebt = /بدهکار|بدهی|مشتری/.test(q);
    const mentionsFlour = /آرد/.test(q);
    const mentionsFuel = /سوخت|گاز|گازوئیل/.test(q);
    const mentionsExpense = /هزینه/.test(q);
    const noneMatched = !mentionsSales && !mentionsDebt && !mentionsFlour && !mentionsFuel && !mentionsExpense;

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);

    if (mentionsSales || noneMatched) {
      const sales = await this.prisma.sale.findMany({
        where: { date: { gte: todayStart, lt: todayEnd }, status: SaleStatus.ACTIVE },
        include: { payments: { include: { paymentMethod: true } } },
      });
      const totalSales = sales.reduce((sum, s) => sum + Number(s.totalAmount), 0);
      let cash = 0;
      let card = 0;
      let credit = 0;
      for (const sale of sales) {
        for (const payment of sale.payments) {
          const amount = Number(payment.amount);
          if (payment.paymentMethod.type === PaymentMethodType.CASH) cash += amount;
          else if (payment.paymentMethod.type === PaymentMethodType.CARD) card += amount;
          else if (payment.paymentMethod.type === PaymentMethodType.CREDIT) credit += amount;
        }
      }
      context.todaySales = { totalSales, cash, card, credit, saleCount: sales.length };
    }

    if (mentionsDebt || noneMatched) {
      const debtReport = await this.customersService.debtReport();
      context.debts = {
        totalDebt: debtReport.totalDebt,
        topDebtors: debtReport.debtors.slice(0, 5).map((d) => ({ name: d.name, balance: d.balance })),
      };
    }

    if (mentionsFlour || noneMatched) {
      const flour = await this.flourInventoryService.getCurrentStock();
      context.flourInventory = { currentStockKg: flour.currentStockKg, minStockKg: flour.minStockKg };
    }

    if (mentionsFuel) {
      const tanks = await this.fuelService.findAllTanks();
      context.fuelTanks = tanks.map((t) => ({ fuelType: t.fuelType, currentLiters: t.currentLiters, capacityLiters: t.capacityLiters }));
    }

    if (mentionsExpense) {
      const monthStart = new Date(todayStart);
      monthStart.setDate(1);
      const expenseReport = await this.expensesService.report(monthStart, todayEnd);
      context.monthlyExpenses = expenseReport;
    }

    return context;
  }

  private buildFallbackAnswer(context: GroundedContext): string {
    const lines: string[] = [];
    const c: any = context;

    if (c.todaySales) {
      lines.push(
        `فروش امروز: جمع ${c.todaySales.totalSales.toLocaleString('fa-IR')} تومان (نقد: ${c.todaySales.cash.toLocaleString('fa-IR')}، کارت: ${c.todaySales.card.toLocaleString('fa-IR')}، نسیه: ${c.todaySales.credit.toLocaleString('fa-IR')}) از ${c.todaySales.saleCount} فاکتور.`,
      );
    }
    if (c.debts) {
      lines.push(`مانده بدهی مشتریان: ${c.debts.totalDebt.toLocaleString('fa-IR')} تومان.`);
    }
    if (c.flourInventory) {
      lines.push(`موجودی فعلی آرد: ${c.flourInventory.currentStockKg} کیلوگرم (حد مجاز: ${c.flourInventory.minStockKg} کیلوگرم).`);
    }
    if (c.fuelTanks) {
      for (const tank of c.fuelTanks) {
        lines.push(`مخزن سوخت ${tank.fuelType}: ${tank.currentLiters} از ${tank.capacityLiters} لیتر.`);
      }
    }
    if (c.monthlyExpenses) {
      lines.push(`هزینه‌های این ماه: ${c.monthlyExpenses.totalAmount.toLocaleString('fa-IR')} تومان (شخصی: ${c.monthlyExpenses.personalAmount.toLocaleString('fa-IR')} تومان).`);
    }

    if (lines.length === 0) {
      return 'اطلاعات کافی در سیستم برای پاسخ به این سوال موجود نیست. لطفاً سوال خود را درباره فروش، بدهی، موجودی آرد/سوخت یا هزینه‌ها دقیق‌تر مطرح کنید.';
    }

    return lines.join('\n');
  }

  private async generateAnswer(question: string, context: GroundedContext): Promise<string> {
    const aiConfig = this.configService.get('ai') as { apiKey?: string; baseUrl: string; model: string };

    if (!aiConfig?.apiKey) {
      return this.buildFallbackAnswer(context);
    }

    try {
      const response = await fetch(`${aiConfig.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${aiConfig.apiKey}` },
        body: JSON.stringify({
          model: aiConfig.model,
          messages: [
            {
              role: 'system',
              content:
                'شما دستیار هوش مند کی نانوایی هستید. فقط بر اساس داده‌های JSON ارائه‌شده پاسخ فارسی بده. اگر داده کافی وجود ندارد، صریحاً بگو اطلاعات کافی موجود نیست. هیچ عددی را از خودت نساز.',
            },
            { role: 'user', content: `داده‌ها: ${JSON.stringify(context)}\n\nسوال: ${question}` },
          ],
          temperature: 0.2,
        }),
      });

      if (!response.ok) return this.buildFallbackAnswer(context);
      const body: any = await response.json();
      const content = body?.choices?.[0]?.message?.content;
      return content || this.buildFallbackAnswer(context);
    } catch {
      return this.buildFallbackAnswer(context);
    }
  }
}
