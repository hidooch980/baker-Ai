import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';
import '../../core/offline/offline_submit.dart';
import '../../core/offline/sync_engine.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> _sales = [];
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
      final response = await ApiClient.instance.dio.get('/sales');
      setState(() {
        _sales = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openNewSale() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewSaleScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _voidSale(String id) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ابطال فروش'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'دلیل ابطال'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.post('/sales/$id/void', data: {'reason': reasonController.text});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فروش')),
      floatingActionButton: FloatingActionButton(onPressed: _openNewSale, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _sales.isEmpty
                    ? const Center(child: Text('هنوز فروشی ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sale = _sales[index];
                          final isVoided = sale['status'] == 'VOIDED';
                          return Card(
                            child: ListTile(
                              title: Text('فاکتور ${sale['docNumber']}'),
                              subtitle: Text('${sale['type']} • ${(sale['date'] as String? ?? '').split('T').first}'),
                              trailing: Text(
                                FaNumbers.formatCurrency(double.tryParse(sale['totalAmount'].toString()) ?? 0),
                                style: TextStyle(decoration: isVoided ? TextDecoration.lineThrough : null, color: isVoided ? Colors.grey : null),
                              ),
                              onLongPress: isVoided ? null : () => _voidSale(sale['id'] as String),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _error;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _customers = [];

  String _type = 'RETAIL';
  String? _customerId;
  String? _paymentMethodId;
  final _paidAmountController = TextEditingController();
  final List<_SaleItemForm> _items = [_SaleItemForm()];

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([dio.get('/products'), dio.get('/payment-methods'), dio.get('/customers')]);
      if (!mounted) return;
      setState(() {
        _products = (results[0].data as List).cast<Map<String, dynamic>>();
        _paymentMethods = (results[1].data as List).cast<Map<String, dynamic>>();
        _customers = (results[2].data as List).cast<Map<String, dynamic>>();
        _isLoadingLookups = false;
      });
    } catch (e) {
      // در حالت آفلاین، داده‌های مرجع از کش محلی خوانده می‌شوند.
      final products = await SyncEngine.instance.cachedReference('products');
      final paymentMethods = await SyncEngine.instance.cachedReference('paymentMethods');
      final customers = await SyncEngine.instance.cachedReference('customers');
      if (!mounted) return;
      setState(() {
        _products = products;
        _paymentMethods = paymentMethods;
        _customers = customers;
        _error = (products.isEmpty || paymentMethods.isEmpty) ? apiErrorMessage(e) : null;
        _isLoadingLookups = false;
      });
    }
  }

  double get _estimatedTotal {
    double total = 0;
    for (final item in _items) {
      final product = _products.firstWhere((p) => p['id'] == item.productId, orElse: () => const {});
      final price = double.tryParse((item.unitPrice?.isNotEmpty == true ? item.unitPrice : product['price']?.toString()) ?? '0') ?? 0;
      final qty = double.tryParse(item.quantity ?? '0') ?? 0;
      final discount = double.tryParse(item.discount ?? '0') ?? 0;
      total += (price * qty) - discount;
    }
    return total;
  }

  Future<void> _submit() async {
    if (_paymentMethodId == null) {
      setState(() => _error = 'روش پرداخت را انتخاب کنید.');
      return;
    }
    final validItems = _items.where((item) => item.productId != null && (double.tryParse(item.quantity ?? '') ?? 0) > 0).toList();
    if (validItems.isEmpty) {
      setState(() => _error = 'حداقل یک قلم فروش را کامل کنید.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await submitOrQueue(
        path: '/sales',
        entity: 'Sale',
        payload: {
          'type': _type,
          if (_customerId != null) 'customerId': _customerId,
          'paymentMethodId': _paymentMethodId,
          if (_paidAmountController.text.trim().isNotEmpty) 'paidAmount': double.tryParse(_paidAmountController.text.trim()),
          'items': validItems
              .map((item) => {
                    'productId': item.productId,
                    'quantity': double.tryParse(item.quantity ?? '0'),
                    if ((item.unitPrice ?? '').isNotEmpty) 'unitPrice': double.tryParse(item.unitPrice!),
                    if ((item.discount ?? '').isNotEmpty) 'discount': double.tryParse(item.discount!),
                  })
              .toList(),
        },
      );
      if (!mounted) return;
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اینترنت در دسترس نیست؛ فروش به صورت آفلاین ذخیره شد و پس از اتصال، خودکار همگام می‌شود.')),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فروش جدید')),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'نوع فروش'),
                  items: const [
                    DropdownMenuItem(value: 'RETAIL', child: Text('خرد')),
                    DropdownMenuItem(value: 'WHOLESALE', child: Text('عمده')),
                    DropdownMenuItem(value: 'ORGANIZATIONAL', child: Text('سازمانی')),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? 'RETAIL'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  decoration: const InputDecoration(labelText: 'مشتری (اختیاری)'),
                  items: _customers.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                  onChanged: (value) => setState(() => _customerId = value),
                ),
                const SizedBox(height: 16),
                Text('اقلام فروش', style: Theme.of(context).textTheme.titleMedium),
                ..._items.asMap().entries.map((entry) => _buildItemRow(entry.key, entry.value)),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_SaleItemForm())),
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن قلم'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethodId,
                  decoration: const InputDecoration(labelText: 'روش پرداخت'),
                  items: _paymentMethods.map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['name'] as String))).toList(),
                  onChanged: (value) => setState(() => _paymentMethodId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paidAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ پرداختی (اختیاری)'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('جمع تخمینی'),
                        Text(FaNumbers.formatCurrency(_estimatedTotal), style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('ثبت فروش'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemRow(int index, _SaleItemForm item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: item.productId,
              decoration: const InputDecoration(labelText: 'محصول'),
              items: _products.map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['name'] as String))).toList(),
              onChanged: (value) => setState(() => item.productId = value),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تعداد'),
                    onChanged: (value) => setState(() => item.quantity = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قیمت واحد (اختیاری)'),
                    onChanged: (value) => setState(() => item.unitPrice = value),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تخفیف (اختیاری)'),
                    onChanged: (value) => setState(() => item.discount = value),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleItemForm {
  String? productId;
  String? quantity;
  String? unitPrice;
  String? discount;
}
