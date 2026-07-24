import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

/// صفحه چانه‌گیری خمیر: فهرست بچ‌های خمیر + ثبت خمیر جدید همراه با تقسیم چانه‌ها.
class DoughScreen extends StatefulWidget {
  const DoughScreen({super.key});

  @override
  State<DoughScreen> createState() => _DoughScreenState();
}

class _DoughScreenState extends State<DoughScreen> {
  List<Map<String, dynamic>> _batches = [];
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
      final response = await ApiClient.instance.dio.get('/dough-batches');
      setState(() {
        _batches = (response.data as List).cast<Map<String, dynamic>>();
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
      appBar: AppBar(title: const Text('چانه‌گیری خمیر')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewDoughBatchScreen()));
          if (created == true) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _batches.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), Center(child: Text('هنوز خمیری ثبت نشده است.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _batches.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final batch = _batches[index];
                            final divisions = (batch['divisions'] as List? ?? []).cast<Map<String, dynamic>>();
                            final producedAt = (batch['producedAt'] as String? ?? '').split('T').first;
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.bakery_dining_outlined),
                                title: Text('خمیر ${batch['doughWeightKg']} کیلوگرم'),
                                subtitle: Text('آرد: ${batch['flourKg']} کیلوگرم — چانه‌ها: ${divisions.length} — $producedAt'),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _DivisionInput {
  String? productId;
  final TextEditingController pieceCount = TextEditingController();
  final TextEditingController pieceWeightG = TextEditingController();
}

class NewDoughBatchScreen extends StatefulWidget {
  const NewDoughBatchScreen({super.key});

  @override
  State<NewDoughBatchScreen> createState() => _NewDoughBatchScreenState();
}

class _NewDoughBatchScreenState extends State<NewDoughBatchScreen> {
  final _flourController = TextEditingController();
  final _waterController = TextEditingController();
  final _saltController = TextEditingController();
  final _yeastController = TextEditingController();
  final _doughWeightController = TextEditingController();
  final List<_DivisionInput> _divisions = [];
  List<Map<String, dynamic>> _products = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await ApiClient.instance.dio.get('/products');
      if (!mounted) return;
      setState(() => _products = (response.data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // فهرست محصولات اختیاری است؛ در صورت خطا فرم بدون انتخاب محصول کار می‌کند.
    }
  }

  Future<void> _submit() async {
    final flour = double.tryParse(_flourController.text.trim()) ?? 0;
    final water = double.tryParse(_waterController.text.trim()) ?? 0;
    final salt = double.tryParse(_saltController.text.trim()) ?? 0;
    final yeast = double.tryParse(_yeastController.text.trim()) ?? 0;
    final doughWeight = double.tryParse(_doughWeightController.text.trim()) ?? 0;
    if (flour <= 0 || water <= 0 || salt <= 0 || yeast <= 0 || doughWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('همه مقادیر باید بزرگ‌تر از صفر باشند.')));
      return;
    }
    final divisions = <Map<String, dynamic>>[];
    for (final division in _divisions) {
      final count = double.tryParse(division.pieceCount.text.trim()) ?? 0;
      final weight = double.tryParse(division.pieceWeightG.text.trim()) ?? 0;
      if (count <= 0 || weight <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعداد و وزن هر چانه باید بزرگ‌تر از صفر باشد.')));
        return;
      }
      divisions.add({
        if (division.productId != null) 'productId': division.productId,
        'pieceCount': count,
        'pieceWeightG': weight,
      });
    }
    setState(() => _isSaving = true);
    try {
      await ApiClient.instance.dio.post('/dough-batches', data: {
        'flourKg': flour,
        'waterLiters': water,
        'saltKg': salt,
        'yeastKg': yeast,
        'doughWeightKg': doughWeight,
        if (divisions.isNotEmpty) 'divisions': divisions,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت خمیر جدید')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _flourController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'آرد مصرفی (کیلوگرم)')),
          const SizedBox(height: 8),
          TextField(controller: _waterController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'آب (لیتر)')),
          const SizedBox(height: 8),
          TextField(controller: _saltController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نمک (کیلوگرم)')),
          const SizedBox(height: 8),
          TextField(controller: _yeastController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مخمر (کیلوگرم)')),
          const SizedBox(height: 8),
          TextField(controller: _doughWeightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'وزن کل خمیر تولیدشده (کیلوگرم)')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('چانه‌ها', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => setState(() => _divisions.add(_DivisionInput())),
                icon: const Icon(Icons.add),
                label: const Text('افزودن چانه'),
              ),
            ],
          ),
          ..._divisions.asMap().entries.map((entry) {
            final index = entry.key;
            final division = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  DropdownButtonFormField<String>(
                    value: division.productId,
                    decoration: const InputDecoration(labelText: 'محصول (اختیاری)'),
                    items: _products
                        .map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['name'] as String? ?? '')))
                        .toList(),
                    onChanged: (value) => setState(() => division.productId = value),
                  ),
                  TextField(controller: division.pieceCount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد چانه')),
                  TextField(controller: division.pieceWeightG, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'وزن هر چانه (گرم)')),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _divisions.removeAt(index)),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ثبت خمیر'),
          ),
        ],
      ),
    );
  }
}
