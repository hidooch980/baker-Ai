import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<Map<String, dynamic>> _productions = [];
  bool _isLoading = true;
  String? _error;

  static const _shiftLabels = {
    'MORNING': 'صبح',
    'AFTERNOON': 'ظهر',
    'EVENING': 'عصر',
    'NIGHT': 'شب',
  };

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
      final response = await ApiClient.instance.dio.get('/production');
      setState(() {
        _productions = (response.data as List).cast<Map<String, dynamic>>();
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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewProductionScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تولید')),
      floatingActionButton: FloatingActionButton(onPressed: _openNew, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _productions.isEmpty
                    ? const Center(child: Text('هنوز تولیدی ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _productions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final production = _productions[index];
                          final items = (production['items'] as List? ?? []).cast<Map<String, dynamic>>();
                          final totalProduced = items.fold<int>(0, (sum, item) => sum + ((item['producedQty'] as num?)?.toInt() ?? 0));
                          return Card(
                            child: ListTile(
                              title: Text('${(production['date'] as String? ?? '').split('T').first} • ${_shiftLabels[production['shift']] ?? production['shift']}'),
                              subtitle: Text('${items.length} قلم محصول'),
                              trailing: Text('${FaNumbers.toFarsi(totalProduced)} عدد'),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class NewProductionScreen extends StatefulWidget {
  const NewProductionScreen({super.key});

  @override
  State<NewProductionScreen> createState() => _NewProductionScreenState();
}

class _NewProductionScreenState extends State<NewProductionScreen> {
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _error;
  List<Map<String, dynamic>> _products = [];

  DateTime _date = DateTime.now();
  String _shift = 'MORNING';
  final _notesController = TextEditingController();
  final List<_ProductionItemForm> _items = [_ProductionItemForm()];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await ApiClient.instance.dio.get('/products');
      setState(() {
        _products = (response.data as List).cast<Map<String, dynamic>>();
        _isLoadingLookups = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoadingLookups = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final validItems = _items.where((item) => item.productId != null && item.producedQty != null && item.producedQty!.isNotEmpty).toList();
    if (validItems.isEmpty) {
      setState(() => _error = 'حداقل یک قلم تولید را کامل کنید.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post('/production', data: {
        'date': _date.toIso8601String(),
        'shift': _shift,
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
        'items': validItems
            .map((item) => {
                  'productId': item.productId,
                  'producedQty': int.tryParse(item.producedQty ?? '0') ?? 0,
                  if ((item.wasteQty ?? '').isNotEmpty) 'wasteQty': int.tryParse(item.wasteQty!),
                  if ((item.returnedQty ?? '').isNotEmpty) 'returnedQty': int.tryParse(item.returnedQty!),
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
      appBar: AppBar(title: const Text('تولید جدید')),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاریخ تولید'),
                  subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
                DropdownButtonFormField<String>(
                  value: _shift,
                  decoration: const InputDecoration(labelText: 'شیفت'),
                  items: const [
                    DropdownMenuItem(value: 'MORNING', child: Text('صبح')),
                    DropdownMenuItem(value: 'AFTERNOON', child: Text('ظهر')),
                    DropdownMenuItem(value: 'EVENING', child: Text('عصر')),
                    DropdownMenuItem(value: 'NIGHT', child: Text('شب')),
                  ],
                  onChanged: (value) => setState(() => _shift = value ?? 'MORNING'),
                ),
                const SizedBox(height: 16),
                Text('اقلام تولید', style: Theme.of(context).textTheme.titleMedium),
                ..._items.asMap().entries.map((entry) => _buildItemRow(entry.key, entry.value)),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ProductionItemForm())),
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن قلم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('ثبت تولید'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemRow(int index, _ProductionItemForm item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: item.productId,
              decoration: const InputDecoration(labelText: 'محصول'),
              items: _products.map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['name'] as String))).toList(),
              onChanged: (value) => setState(() => item.productId = value),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تولید شده'),
                    onChanged: (value) => setState(() => item.producedQty = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ضایعات (اختیاری)'),
                    onChanged: (value) => setState(() => item.wasteQty = value),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'برگشتی (اختیاری)'),
                    onChanged: (value) => setState(() => item.returnedQty = value),
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

class _ProductionItemForm {
  String? productId;
  String? producedQty;
  String? wasteQty;
  String? returnedQty;
}
