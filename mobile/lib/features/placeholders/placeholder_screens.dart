import 'package:flutter/material.dart';

/// این صفحات موقتاً خالی هستند و در فازهای بعدی (۲ تا ۶) با اتصال واقعی به API تکمیل می‌شوند.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('$title در فازهای بعدی تکمیل می‌شود.'),
          ],
        ),
      ),
    );
  }
}

class SalesPlaceholderScreen extends StatelessWidget {
  const SalesPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(title: 'فروش', icon: Icons.point_of_sale);
}

class ProductionPlaceholderScreen extends StatelessWidget {
  const ProductionPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(title: 'تولید', icon: Icons.bakery_dining);
}

class InventoryPlaceholderScreen extends StatelessWidget {
  const InventoryPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(title: 'انبار', icon: Icons.inventory_2);
}

class FinancePlaceholderScreen extends StatelessWidget {
  const FinancePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(title: 'مالی', icon: Icons.account_balance_wallet);
}

class MorePlaceholderScreen extends StatelessWidget {
  const MorePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(title: 'بیشتر', icon: Icons.more_horiz);
}
