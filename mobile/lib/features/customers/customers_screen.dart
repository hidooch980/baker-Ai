import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> _customers = [];
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
      final response = await ApiClient.instance.dio.get('/customers');
      setState(() {
        _customers = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _createCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isCredit = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('مشتری جدید'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'شماره تلفن (اختیاری)'), textDirection: TextDirection.ltr),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مشتری اعتباری (نسیه)'),
                value: isCredit,
                onChanged: (value) => setDialogState(() => isCredit = value),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
          ],
        );
      }),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/customers', data: {
        'name': nameController.text.trim(),
        if (phoneController.text.trim().isNotEmpty) 'phone': phoneController.text.trim(),
        'isCredit': isCredit,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _addTransaction(String customerId) async {
    String type = 'PAYMENT';
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('تراکنش حساب'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'نوع'),
                items: const [
                  DropdownMenuItem(value: 'PAYMENT', child: Text('دریافت')),
                  DropdownMenuItem(value: 'DEBT', child: Text('بدهی جدید')),
                  DropdownMenuItem(value: 'SETTLEMENT', child: Text('تسویه تمام')),
                ],
                onChanged: (value) => setDialogState(() => type = value ?? 'PAYMENT'),
              ),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلف')),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
          ],
        );
      }),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/customers/$customerId/transactions', data: {
        'type': type,
        'amount': double.tryParse(amountController.text.trim()) ?? 0,
        if (noteController.text.trim().isNotEmpty) 'note': noteController.text.trim(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _showDebtReport() async {
    try {
      final response = await ApiClient.instance.dio.get('/customers/debts/report');
      final data = response.data as Map<String, dynamic>;
      final debtors = (data['debtors'] as List).cast<Map<String, dynamic>>();
      final totalDebt = double.tryParse(data['totalDebt'].toString()) ?? 0;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('گزارش بدهکاران'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('جمع کل بدهی: ${FaNumbers.formatCurrency(totalDebt)}'),
                const Divider(),
                ...debtors.map((d) => ListTile(title: Text(d['name'] as String), trailing: Text(FaNumbers.formatCurrency(double.tryParse(d['balance'].toString()) ?? 0)))),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشتریان / بدهکاران'),
        actions: [IconButton(icon: const Icon(Icons.summarize_outlined), onPressed: _showDebtReport)],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createCustomer, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _customers.isEmpty
                    ? const Center(child: Text('هنوز مشتریی ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final customer = _customers[index];
                          final balance = double.tryParse(customer['balance'].toString()) ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(customer['name'] as String),
                              subtitle: Text(customer['phone'] as String? ?? ''),
                              trailing: Text(
                                FaNumbers.formatCurrency(balance),
                                style: TextStyle(color: balance > 0 ? Colors.red : null),
                              ),
                              onTap: () => _addTransaction(customer['id'] as String),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
