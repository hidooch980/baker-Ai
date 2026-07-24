import 'package:flutter/material.dart';
import '../customers/customers_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../purchases/purchases_screen.dart';
import '../employees/employees_screen.dart';
import '../payroll/payroll_screen.dart';
import '../dough/dough_screen.dart';
import '../daily_closing/daily_closing_screen.dart';

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
          const _SectionHeader(title: 'تولید'),
          ListTile(
            leading: const Icon(Icons.bakery_dining_outlined),
            title: const Text('چانه‌گیری خمیر'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoughScreen())),
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
          _ComingSoonTile(icon: Icons.bar_chart_outlined, title: 'گزارش‌ها'),
          const Divider(),
          const _SectionHeader(title: 'سایر'),
          _ComingSoonTile(icon: Icons.notifications_outlined, title: 'اعلان‌ها'),
          _ComingSoonTile(icon: Icons.smart_toy_outlined, title: 'دستیار هوشمند نانوایی'),
          _ComingSoonTile(icon: Icons.sync_outlined, title: 'وضعیت همگام‌سازی'),
          _ComingSoonTile(icon: Icons.backup_outlined, title: 'پشتیبان‌گیری'),
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

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Text('به‌زودی', style: TextStyle(color: Colors.grey, fontSize: 12)),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('این بخش به‌زودی افزوده می‌شود.'))),
    );
  }
}
