import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _paymentMethods = [];
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
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([dio.get('/suppliers'), dio.get('/payment-methods')]);
      setState(() {
        _suppliers = (results[0].data as List).cast<Map<String, dynamic>>();
        _paymentMethods = (results[1].data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _createSupplier() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final goodsTypeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تامین‌کننده جدید'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'شماره تلفن (اختیاری)'), textDirection: TextDirection.ltr),
            TextField(controller: goodsTypeController, decoration: const InputDecoration(labelText: 'نوع کالا (اختیاری)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
        ],
      ),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/suppliers', data: {
        'name': nameController.text.trim(),
        if (phoneController.text.trim().isNotEmpty) 'phone': phoneController.text.trim(),
        if (goodsTypeController.text.trim().isNotEmpty) 'goodsType': goodsTypeController.text.trim(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _recordPayment(String supplierId) async {
    final amountController = TextEditingController();
    String? paymentMethodId = _paymentMethods.isNotEmpty ? _paymentMethods.first['id'] as String : null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('پرداخت به تامین‌کننده'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلف')),
              DropdownButtonFormField<String>(
                initialValue: paymentMethodId,
                decoration: const InputDecoration(labelText: 'روش پرداخت'),
                items: _paymentMethods.map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['name'] as String))).toList(),
                onChanged: (value) => setDialogState(() => paymentMethodId = value),
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
    if (result != true || paymentMethodId == null) return;
    try {
      await ApiClient.instance.dio.post('/suppliers/$supplierId/payments', data: {
        'amount': double.tryParse(amountController.text.trim()) ?? 0,
        'paymentMethodId': paymentMethodId,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _showDebtReport() async {
    try {
      final response = await ApiClient.instance.dio.get('/suppliers/debts/report');
      final data = response.data as Map<String, dynamic>;
      final creditors = (data['creditors'] as List).cast<Map<String, dynamic>>();
      final totalPayable = double.tryParse(data['totalPayable'].toString()) ?? 0;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('گزارش بدهی به تامین‌کنندگان'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('جمع کل بدهی: ${FaNumbers.formatCurrency(totalPayable)}'),
                const Divider(),
                ...creditors.map((s) => ListTile(title: Text(s['name'] as String), trailing: Text(FaNumbers.formatCurrency(double.tryParse(s['balance'].toString()) ?? 0)))),
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
        title: const Text('تامین‌کنندگان'),
        actions: [IconButton(icon: const Icon(Icons.summarize_outlined), onPressed: _showDebtReport)],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createSupplier, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _suppliers.isEmpty
                    ? const Center(child: Text('هنوز تامین‌کننده‌ای ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _suppliers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final supplier = _suppliers[index];
                          final balance = double.tryParse(supplier['balance'].toString()) ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(supplier['name'] as String),
                              subtitle: Text(supplier['goodsType'] as String? ?? ''),
                              trailing: Text(
                                FaNumbers.formatCurrency(balance),
                                style: TextStyle(color: balance > 0 ? Colors.red : null),
                              ),
                              onTap: () => _recordPayment(supplier['id'] as String),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
