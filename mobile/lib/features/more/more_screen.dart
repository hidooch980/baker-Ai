import 'package:flutter/material.dart';
import '../customers/customers_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../purchases/purchases_screen.dart';
import '../employees/employees_screen.dart';
import '../payroll/payroll_screen.dart';
import '../dough/dough_screen.dart';
import '../daily_closing/daily_closing_screen.dart';
import '../reports/reports_screen.dart';
import '../notifications/notifications_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../sync/sync_status_screen.dart';
import '../backup/backup_screen.dart';
import '../products/products_screen.dart';
import '../payment_methods/payment_methods_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بیشتر')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'مالی و طرف حساب'),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('مشتریان / بدهکاران'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomersScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('تامین‌کنندگان'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('خریدها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PurchasesScreen())),
          ),
          const Divider(),
          const _SectionHeader(title: 'تولید و محصولات'),
          ListTile(
            leading: const Icon(Icons.bakery_dining_outlined),
            title: const Text('چانه‌گیری خمیر'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoughScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.breakfast_dining_outlined),
            title: const Text('مدیریت محصولات و قیمت‌ها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('روش‌های پرداخت'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
          ),
          const Divider(),
          const _SectionHeader(title: 'پرسنل و حقوق'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('کارمندان'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmployeesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('حقوق و دستمزد'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayrollScreen())),
          ),
          const Divider(),
          const _SectionHeader(title: 'گزارش‌ها و بستن روز'),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('بستن روز'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyClosingScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('گزارش‌ها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          const Divider(),
          const _SectionHeader(title: 'سایر'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('اعلان‌ها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('دستیار هوشمند نانوایی'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiChatScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('وضعیت همگام‌سازی'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('پشتیبان‌گیری'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
