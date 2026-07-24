import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

const _paymentTypeLabels = {
  'CASH': 'نقدی',
  'CARD': 'کارتخوان',
  'CREDIT': 'نسیه',
};

/// مدیریت روش‌های پرداخت: فهرست و افزودن روش جدید.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _methods = [];
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
      final response = await ApiClient.instance.dio.get('/payment-methods');
      setState(() {
        _methods = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _addMethod() async {
    final nameController = TextEditingController();
    String type = 'CASH';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('روش پرداخت جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام (مثلاً کارتخوان ملت) *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'نوع'),
                items: _paymentTypeLabels.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => setDialogState(() => type = value ?? 'CASH'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام روش پرداخت الزامی است.')));
      return;
    }
    try {
      await ApiClient.instance.dio.post('/payment-methods', data: {'name': name, 'type': type});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('روش پرداخت ثبت شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'CARD':
        return Icons.credit_card_outlined;
      case 'CREDIT':
        return Icons.receipt_long_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('روش‌های پرداخت')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMethod,
        icon: const Icon(Icons.add),
        label: const Text('روش جدید'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _methods.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), Center(child: Text('روش پرداختی ثبت نشده است.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _methods.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final method = _methods[index];
                            final type = method['type'] as String?;
                            return Card(
                              child: ListTile(
                                leading: Icon(_iconFor(type)),
                                title: Text(method['name']?.toString() ?? ''),
                                subtitle: Text(_paymentTypeLabels[type] ?? type ?? ''),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
