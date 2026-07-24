import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';
import '../../core/offline/sync_engine.dart';

const _purchaseCategoryLabels = {
  'FLOUR': 'آرد',
  'MATERIAL': 'مواد اولیه',
  'FUEL': 'سوخت',
  'EQUIPMENT': 'تجهیزات',
  'OTHER': 'سایر',
};

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Map<String, dynamic>> _purchases = [];
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
      final response = await ApiClient.instance.dio.get('/purchases');
      setState(() {
        _purchases = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewPurchaseScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خریدها')),
      floatingActionButton: FloatingActionButton(onPressed: _openNew, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _purchases.isEmpty
                    ? const Center(child: Text('هنوز خریدی ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _purchases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final purchase = _purchases[index];
                          final debt = double.tryParse(purchase['debtAmount'].toString()) ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text('فاکتور ${purchase['docNumber']}'),
                              subtitle: Text('${_purchaseCategoryLabels[purchase['category']] ?? purchase['category']} • ${(purchase['date'] as String? ?? '').split('T').first}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(FaNumbers.formatCurrency(double.tryParse(purchase['totalAmount'].toString()) ?? 0)),
                                  if (debt > 0) Text('بدهی: ${FaNumbers.formatCurrency(debt)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _error;
  List<Map<String, dynamic>> _suppliers = [];

  String _category = 'MATERIAL';
  String? _supplierId;
  final _invoiceController = TextEditingController();
  final _discountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final List<_PurchaseItemForm> _items = [_PurchaseItemForm()];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final response = await ApiClient.instance.dio.get('/suppliers');
      if (!mounted) return;
      setState(() {
        _suppliers = (response.data as List).cast<Map<String, dynamic>>();
        _isLoadingLookups = false;
      });
    } catch (e) {
      // در حالت آفلاین، تامین‌کنندگان از کش محلی خوانده می‌شوند.
      final cached = await SyncEngine.instance.cachedReference('suppliers');
      if (!mounted) return;
      setState(() {
        _suppliers = cached;
        _isLoadingLookups = false;
      });
    }
  }

  Future<void> _submit() async {
    final validItems = _items.where((item) => item.itemName != null && item.itemName!.isNotEmpty && item.quantity != null).toList();
    if (validItems.isEmpty) {
      setState(() => _error = 'حداقل یک قلم خرید را کامل کنید.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post('/purchases', data: {
        if (_invoiceController.text.trim().isNotEmpty) 'invoiceNumber': _invoiceController.text.trim(),
        if (_supplierId != null) 'supplierId': _supplierId,
        'category': _category,
        if (_discountController.text.trim().isNotEmpty) 'discount': double.tryParse(_discountController.text.trim()),
        if (_paidAmountController.text.trim().isNotEmpty) 'paidAmount': double.tryParse(_paidAmountController.text.trim()),
        'items': validItems
            .map((item) => {
                  'itemName': item.itemName,
                  'quantity': double.tryParse(item.quantity ?? '0') ?? 0,
                  'unit': item.unit ?? 'کیلوگرم',
                  'unitPrice': double.tryParse(item.unitPrice ?? '0') ?? 0,
                })
            .toList(),
      });
      if (!mounted) return;
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
      appBar: AppBar(title: const Text('خرید جدید')),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'دسته'),
                  items: _purchaseCategoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (value) => setState(() => _category = value ?? 'MATERIAL'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'تامین‌کننده (اختیاری)'),
                  items: _suppliers.map((s) => DropdownMenuItem<String>(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                  onChanged: (value) => setState(() => _supplierId = value),
                ),
                const SizedBox(height: 12),
                TextField(controller: _invoiceController, decoration: const InputDecoration(labelText: 'شماره فاکتور (اختیاری)')),
                const SizedBox(height: 16),
                Text('اقلام خرید', style: Theme.of(context).textTheme.titleMedium),
                ..._items.asMap().entries.map((entry) => _buildItemRow(entry.key, entry.value)),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_PurchaseItemForm())),
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن قلم'),
                ),
                const SizedBox(height: 12),
                TextField(controller: _discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تخفیف (اختیاری)')),
                const SizedBox(height: 12),
                TextField(controller: _paidAmountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار پرداخت‌شده (اختیاری)')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('ثبت خرید'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemRow(int index, _PurchaseItemForm item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'نام قلم'),
              onChanged: (value) => setState(() => item.itemName = value),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مقدار'),
                  onChanged: (value) => setState(() => item.quantity = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'واحد'),
                  onChanged: (value) => setState(() => item.unit = value),
                ),
              ),
            ]),
            Row(children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قیمت واحد'),
                  onChanged: (value) => setState(() => item.unitPrice = value),
                ),
              ),
              if (_items.length > 1)
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PurchaseItemForm {
  String? itemName;
  String? quantity;
  String? unit;
  String? unitPrice;
}
