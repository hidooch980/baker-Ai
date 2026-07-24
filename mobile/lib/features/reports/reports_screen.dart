import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

String _dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

const _profitLossLabels = {
  'revenue': 'درآمد (فروش)',
  'costOfGoods': 'بهای خرید کالا',
  'grossProfit': 'سود ناخالص',
  'operatingExpenses': 'هزینه‌های جاری',
  'payrollCost': 'هزینه حقوق و دستمزد',
  'personalWithdrawals': 'برداشت شخصی',
  'netProfit': 'سود خالص',
};

/// صفحه گزارش‌ها: سود و زیان + فروش به تفکیک محصول در بازه دلخواه.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('گزارش‌ها'),
          bottom: const TabBar(tabs: [
            Tab(text: 'سود و زیان'),
            Tab(text: 'فروش محصولات'),
          ]),
        ),
        body: const TabBarView(children: [
          _ProfitLossTab(),
          _SalesReportTab(),
        ]),
      ),
    );
  }
}

class _ProfitLossTab extends StatefulWidget {
  const _ProfitLossTab();

  @override
  State<_ProfitLossTab> createState() => _ProfitLossTabState();
}

class _ProfitLossTabState extends State<_ProfitLossTab> {
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 6)), end: DateTime.now());
  Map<String, dynamic>? _report;
  bool _isLoading = false;
  String? _error;

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
      final response = await ApiClient.instance.dio.get('/reports/profit-loss', queryParameters: {
        'startDate': _dateOnly(_range.start),
        'endDate': _dateOnly(_range.end),
      });
      setState(() {
        _report = response.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text('بازه: ${_dateOnly(_range.start)} تا ${_dateOnly(_range.end)}'),
        ),
        const SizedBox(height: 16),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_report != null && !_isLoading)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _profitLossLabels.entries
                    .where((entry) => _report!.containsKey(entry.key))
                    .map((entry) {
                  final amount = double.tryParse(_report![entry.key].toString()) ?? 0;
                  final isNet = entry.key == 'netProfit';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.value, style: isNet ? const TextStyle(fontWeight: FontWeight.bold) : null),
                        Text(
                          FaNumbers.formatCurrency(amount),
                          style: TextStyle(
                            fontWeight: isNet ? FontWeight.bold : FontWeight.normal,
                            color: isNet ? (amount >= 0 ? Colors.green : Colors.red) : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _SalesReportTab extends StatefulWidget {
  const _SalesReportTab();

  @override
  State<_SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends State<_SalesReportTab> {
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 6)), end: DateTime.now());
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = false;
  String? _error;

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
      final response = await ApiClient.instance.dio.get('/reports/sales', queryParameters: {
        'startDate': _dateOnly(_range.start),
        'endDate': _dateOnly(_range.end),
      });
      setState(() {
        _rows = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text('بازه: ${_dateOnly(_range.start)} تا ${_dateOnly(_range.end)}'),
        ),
        const SizedBox(height: 16),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (!_isLoading && _error == null && _rows.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('در این بازه فروشی ثبت نشده است.'))),
        ..._rows.map((row) {
          final total = double.tryParse(row['total'].toString()) ?? 0;
          return Card(
            child: ListTile(
              title: Text(row['productName'] as String? ?? ''),
              subtitle: Text('تعداد: ${row['quantity']}'),
              trailing: Text(FaNumbers.formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }),
      ],
    );
  }
}
