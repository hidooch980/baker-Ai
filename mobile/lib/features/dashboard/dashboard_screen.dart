import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

/// داشبورد اصلی متصل به دیتای واقعی فروش/صندوق/موجودی انبار.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  double _todaySales = 0;
  double _cashBalance = 0;
  double _flourStockKg = 0;
  int _lowStockAlerts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([
        dio.get('/sales'),
        dio.get('/cash-box/open'),
        dio.get('/flour-inventory'),
        dio.get('/inventory'),
      ]);

      final sales = (results[0].data as List).cast<Map<String, dynamic>>();
      final now = DateTime.now();
      final todayTotal = sales.where((sale) {
        final date = DateTime.tryParse(sale['date'] as String? ?? '');
        return date != null && date.year == now.year && date.month == now.month && date.day == now.day && sale['status'] != 'VOIDED';
      }).fold<double>(0, (sum, sale) => sum + (double.tryParse(sale['totalAmount'].toString()) ?? 0));

      final cashBox = results[1].data as Map<String, dynamic>?;
      final openingBalance = cashBox == null ? 0.0 : (double.tryParse(cashBox['openingBalance'].toString()) ?? 0);

      final flour = results[2].data as Map<String, dynamic>?;
      final flourStock = flour == null ? 0.0 : (double.tryParse(flour['currentStockKg'].toString()) ?? 0);
      final flourMin = flour == null ? 0.0 : (double.tryParse(flour['minStockKg'].toString()) ?? 0);

      final materials = (results[3].data as List).cast<Map<String, dynamic>>();
      final lowMaterials = materials.where((m) => (double.tryParse(m['currentStock'].toString()) ?? 0) <= (double.tryParse(m['minStock'].toString()) ?? 0)).length;

      setState(() {
        _todaySales = todayTotal;
        _cashBalance = openingBalance;
        _flourStockKg = flourStock;
        _lowStockAlerts = lowMaterials + (flourStock <= flourMin ? 1 : 0);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('داشبورد')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  _DashboardCard(title: 'فروش امروز', value: FaNumbers.formatCurrency(_todaySales)),
                  const SizedBox(height: 12),
                  _DashboardCard(title: 'موجودی صندوق باز', value: FaNumbers.formatCurrency(_cashBalance)),
                  const SizedBox(height: 12),
                  _DashboardCard(title: 'موجودی آرد', value: '${FaNumbers.toFarsi(_flourStockKg.toStringAsFixed(0))} کیلوگرم'),
                  const SizedBox(height: 12),
                  _DashboardCard(
                    title: 'هشدارهای موجودی',
                    value: _lowStockAlerts == 0 ? 'موردی یافت نشد' : '${FaNumbers.toFarsi(_lowStockAlerts)} مورد',
                  ),
                ],
              ),
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
