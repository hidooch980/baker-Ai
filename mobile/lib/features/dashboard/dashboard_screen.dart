import 'package:flutter/material.dart';
import '../../core/localization/fa_numbers.dart';

/// داشبورد اصلی. در فاز ۲ به دیتای واقعی Sales/Production/CashBox متصل می‌شود.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('داشبورد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DashboardCard(title: 'فروش امروز', value: FaNumbers.formatCurrency(0)),
          const SizedBox(height: 12),
          _DashboardCard(title: 'موجودی صندوق', value: FaNumbers.formatCurrency(0)),
          const SizedBox(height: 12),
          _DashboardCard(title: 'موجودی آرد', value: '—'),
          const SizedBox(height: 12),
          _DashboardCard(title: 'هشدارهای مهم', value: 'موردی یافت نشد'),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
