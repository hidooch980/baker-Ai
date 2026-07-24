import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

const _currencyKeys = {
  'totalSales',
  'cashSales',
  'cardSales',
  'creditSales',
  'totalExpenses',
  'personalWithdrawals',
  'totalPurchases',
  'cashBalance',
  'approxProfit',
};

const _totalLabels = {
  'totalSales': 'جمع فروش',
  'cashSales': 'فروش نقدی',
  'cardSales': 'فروش کارتخوان',
  'creditSales': 'فروش نسیه',
  'totalExpenses': 'جمع هزینه‌ها',
  'personalWithdrawals': 'برداشت شخصی',
  'totalPurchases': 'جمع خریدها',
  'cashBalance': 'مانده صندوق',
  'approxProfit': 'سود تقریبی',
  'totalProduction': 'تولید کل (عدد)',
  'wasteQty': 'ضایعات (عدد)',
  'flourConsumedKg': 'مصرف آرد (کیلوگرم)',
  'fuelConsumedLiters': 'مصرف سوخت (لیتر)',
};

String _formatValue(String key, dynamic value) {
  if (_currencyKeys.contains(key)) {
    return FaNumbers.formatCurrency(double.tryParse(value?.toString() ?? '0') ?? 0);
  }
  return value?.toString() ?? '-';
}

String _dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// صفحه بستن روز: پیش‌نمایش ترازنامه روز، بستن و قفل روز، و بازکردن با ذکر دلیل.
class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  List<Map<String, dynamic>> _closings = [];
  bool _isLoading = true;
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
      final response = await ApiClient.instance.dio.get('/daily-closing');
      setState(() {
        _closings = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<DateTime?> _pickDate() {
    return showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
  }

  Future<void> _preview() async {
    final picked = await _pickDate();
    if (picked == null || !mounted) return;
    try {
      final response = await ApiClient.instance.dio.get('/daily-closing/preview', queryParameters: {'date': _dateOnly(picked)});
      if (!mounted) return;
      final totals = response.data as Map<String, dynamic>;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('پیش‌نمایش روز ${_dateOnly(picked)}'),
          content: SingleChildScrollView(child: _TotalsList(data: totals)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _closeDay() async {
    final picked = await _pickDate();
    if (picked == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بستن روز'),
        content: Text('روز ${_dateOnly(picked)} بسته و قفل شود؟ پس از بستن، داده‌های این روز قابل ویرایش نخواهند بود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('بستن روز')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.post('/daily-closing/close', data: {'date': _dateOnly(picked)});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('روز با موفقیت بسته شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _reopen(Map<String, dynamic> closing) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بازکردن روز'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'دلیل بازکردن (الزامی)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('بازکردن')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای بازکردن روز، ذکر دلیل الزامی است.')));
      return;
    }
    try {
      final dateStr = (closing['date'] as String? ?? '').split('T').first;
      await ApiClient.instance.dio.post('/daily-closing/reopen', data: {'date': dateStr, 'reason': reason});
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  void _showDetails(Map<String, dynamic> closing) {
    final isLocked = closing['isLocked'] == true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('روز ${(closing['date'] as String? ?? '').split('T').first}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isLocked ? 'وضعیت: بسته و قفل‌شده' : 'وضعیت: باز', style: TextStyle(color: isLocked ? Colors.red : Colors.green)),
            const SizedBox(height: 8),
            _TotalsList(data: closing),
          ]),
        ),
        actions: [
          if (isLocked)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reopen(closing);
              },
              child: const Text('بازکردن روز', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بستن روز')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ElevatedButton.icon(onPressed: _preview, icon: const Icon(Icons.visibility_outlined), label: const Text('پیش‌نمایش ترازنامه روز')),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(onPressed: _closeDay, icon: const Icon(Icons.lock_outline), label: const Text('بستن و قفل روز')),
                      const SizedBox(height: 16),
                      Text('روزهای بسته‌شده', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_closings.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('هنوز روزی بسته نشده است.'))),
                      ..._closings.map((closing) {
                        final isLocked = closing['isLocked'] == true;
                        return Card(
                          child: ListTile(
                            leading: Icon(isLocked ? Icons.lock_outline : Icons.lock_open_outlined, color: isLocked ? Colors.red : Colors.green),
                            title: Text((closing['date'] as String? ?? '').split('T').first),
                            subtitle: Text('سود تقریبی: ${_formatValue('approxProfit', closing['approxProfit'])}'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => _showDetails(closing),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _TotalsList extends StatelessWidget {
  const _TotalsList({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rows = _totalLabels.entries.where((entry) => data.containsKey(entry.key)).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows
          .map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.value),
                    Text(_formatValue(entry.key, data[entry.key]), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
