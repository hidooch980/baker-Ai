import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/offline/sync_engine.dart';
import '../dashboard/dashboard_screen.dart';
import '../sales/sales_screen.dart';
import '../production/production_screen.dart';
import '../inventory/inventory_screen.dart';
import '../finance/finance_screen.dart';
import '../purchases/purchases_screen.dart';
import '../more/more_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    DashboardScreen(),
    SalesScreen(),
    ProductionScreen(),
    InventoryScreen(),
    FinanceScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // راه‌اندازی موتور همگام‌سازی آفلاین پس از ورود کاربر.
    unawaited(SyncEngine.instance.start());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'فروش'),
          NavigationDestination(icon: Icon(Icons.bakery_dining_outlined), selectedIcon: Icon(Icons.bakery_dining), label: 'تولید'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'انبار'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'مالی'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'بیشتر'),
        ],
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('فروش جدید'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSaleScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bakery_dining),
              title: const Text('تولید جدید'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewProductionScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('خرید جدید'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewPurchaseScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('هزینه جدید'),
              onTap: () {
                Navigator.pop(sheetContext);
                DefaultTabController.of(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
