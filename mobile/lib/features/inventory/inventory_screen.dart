import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('انبار'),
          bottom: const TabBar(tabs: [
            Tab(text: 'آرد'),
            Tab(text: 'سوخت'),
            Tab(text: 'مواد اولیه'),
          ]),
        ),
        body: const TabBarView(children: [
          _FlourTab(),
          _FuelTab(),
          _MaterialsTab(),
        ]),
      ),
    );
  }
}

class _FlourTab extends StatefulWidget {
  const _FlourTab();

  @override
  State<_FlourTab> createState() => _FlourTabState();
}

class _FlourTabState extends State<_FlourTab> {
  Map<String, dynamic>? _flour;
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
      final response = await ApiClient.instance.dio.get('/flour-inventory');
      setState(() {
        _flour = response.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _addStock() async {
    final bagCountController = TextEditingController();
    final bagWeightController = TextEditingController();
    final totalWeightController = TextEditingController();
    final pricePerBagController = TextEditingController();
    final invoiceController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن موجودی آرد'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: bagCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد کیسه (اختیاری)')),
            TextField(controller: bagWeightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'وزن هر کیسه - کیلوگرم (اختیاری)')),
            TextField(controller: totalWeightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'وزن کل - کیلوگرم')),
            TextField(controller: pricePerBagController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت هر کیسه (اختیاری)')),
            TextField(controller: invoiceController, decoration: const InputDecoration(labelText: 'شماره فاکتور (اختیاری)')),
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
      await ApiClient.instance.dio.post('/flour-inventory/stock', data: {
        if (bagCountController.text.trim().isNotEmpty) 'bagCount': int.tryParse(bagCountController.text.trim()),
        if (bagWeightController.text.trim().isNotEmpty) 'bagWeightKg': double.tryParse(bagWeightController.text.trim()),
        'totalWeightKg': double.tryParse(totalWeightController.text.trim()) ?? 0,
        if (pricePerBagController.text.trim().isNotEmpty) 'pricePerBag': double.tryParse(pricePerBagController.text.trim()),
        if (invoiceController.text.trim().isNotEmpty) 'invoiceNumber': invoiceController.text.trim(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _setMinStock() async {
    final controller = TextEditingController(text: _flour?['minStockKg']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنزیم حد مجاز آرد'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حداقل موجودی - کیلوگرم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
        ],
      ),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/flour-inventory/min-stock', data: {'minStockKg': double.tryParse(controller.text.trim()) ?? 0});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    final currentStock = _flour == null ? 0.0 : (double.tryParse(_flour!['currentStockKg'].toString()) ?? 0);
    final minStock = _flour == null ? 0.0 : (double.tryParse(_flour!['minStockKg'].toString()) ?? 0);
    final isLow = currentStock <= minStock;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isLow ? Colors.red.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('موجودی فعلی آرد', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('${FaNumbers.toFarsi(currentStock.toStringAsFixed(0))} کیلوگرم', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('حد مجاز: ${FaNumbers.toFarsi(minStock.toStringAsFixed(0))} کیلوگرم'),
                if (isLow) const Padding(padding: EdgeInsets.only(top: 8), child: Text('هشدار: موجودی آرد پایین است', style: TextStyle(color: Colors.red))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _addStock, icon: const Icon(Icons.add), label: const Text('افزودن موجودی')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _setMinStock, icon: const Icon(Icons.tune), label: const Text('تنزیم حد مجاز')),
        ],
      ),
    );
  }
}

class _FuelTab extends StatefulWidget {
  const _FuelTab();

  @override
  State<_FuelTab> createState() => _FuelTabState();
}

class _FuelTabState extends State<_FuelTab> {
  List<Map<String, dynamic>> _tanks = [];
  bool _isLoading = true;
  String? _error;

  static const _fuelLabels = {'DIESEL': 'گازوئیل', 'NATURAL_GAS': 'گاز طبیعی', 'GASOLINE': 'بنزین', 'OTHER': 'سایر'};

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
      final response = await ApiClient.instance.dio.get('/fuel-tanks');
      setState(() {
        _tanks = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _createTank() async {
    String fuelType = 'DIESEL';
    final capacityController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('مخزن سوخت جدید'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: fuelType,
              decoration: const InputDecoration(labelText: 'نوع سوخت'),
              items: _fuelLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (value) => setDialogState(() => fuelType = value ?? 'DIESEL'),
            ),
            TextField(controller: capacityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ظرفیت - لیتر')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
          ],
        );
      }),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/fuel-tanks', data: {
        'fuelType': fuelType,
        'capacityLiters': double.tryParse(capacityController.text.trim()) ?? 0,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _tankAction(String tankId, {required bool isAdd}) async {
    final litersController = TextEditingController();
    final priceOrNoteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdd ? 'افزودن سوخت' : 'مصرف سوخت'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: litersController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'لیتر')),
          TextField(controller: priceOrNoteController, decoration: InputDecoration(labelText: isAdd ? 'قیمت هر لیتر (اختیاری)' : 'یادداشت (اختیاری)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
        ],
      ),
    );
    if (result != true) return;
    try {
      final liters = double.tryParse(litersController.text.trim()) ?? 0;
      if (isAdd) {
        await ApiClient.instance.dio.post('/fuel-tanks/$tankId/add', data: {
          'liters': liters,
          if (priceOrNoteController.text.trim().isNotEmpty) 'pricePerLiter': double.tryParse(priceOrNoteController.text.trim()),
        });
      } else {
        await ApiClient.instance.dio.post('/fuel-tanks/$tankId/consume', data: {
          'liters': liters,
          if (priceOrNoteController.text.trim().isNotEmpty) 'note': priceOrNoteController.text.trim(),
        });
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _createTank, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _tanks.isEmpty
            ? const Center(child: Text('هنوز مخزن سوختی ثبت نشده است.'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _tanks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tank = _tanks[index];
                  final current = double.tryParse(tank['currentLiters'].toString()) ?? 0;
                  final capacity = double.tryParse(tank['capacityLiters'].toString()) ?? 1;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_fuelLabels[tank['fuelType']] ?? tank['fuelType'], style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: capacity == 0 ? 0 : (current / capacity).clamp(0, 1)),
                        const SizedBox(height: 4),
                        Text('${FaNumbers.toFarsi(current.toStringAsFixed(0))} از ${FaNumbers.toFarsi(capacity.toStringAsFixed(0))} لیتر'),
                        const SizedBox(height: 8),
                        Row(children: [
                          TextButton(onPressed: () => _tankAction(tank['id'] as String, isAdd: true), child: const Text('افزودن')),
                          TextButton(onPressed: () => _tankAction(tank['id'] as String, isAdd: false), child: const Text('مصرف')),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MaterialsTab extends StatefulWidget {
  const _MaterialsTab();

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  String? _error;

  static const _txTypeLabels = {
    'INITIAL': 'اولیه',
    'PURCHASE': 'خرید',
    'RECEIVE': 'دریافت',
    'TRANSFER': 'انتقال',
    'CONSUMPTION': 'مصرف',
    'ADJUSTMENT': 'اصلاح',
    'WASTE': 'ضایعات',
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
      final response = await ApiClient.instance.dio.get('/inventory');
      setState(() {
        _materials = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _createMaterial() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final minStockController = TextEditingController();
    final priceController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ماده اولیه جدید'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام')),
            TextField(controller: unitController, decoration: const InputDecoration(labelText: 'واحد (مثلاً کیلوگرم)')),
            TextField(controller: minStockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد مجاز (اختیاری)')),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت (اختیاری)')),
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
      await ApiClient.instance.dio.post('/inventory', data: {
        'name': nameController.text.trim(),
        'unit': unitController.text.trim(),
        if (minStockController.text.trim().isNotEmpty) 'minStock': double.tryParse(minStockController.text.trim()),
        if (priceController.text.trim().isNotEmpty) 'price': double.tryParse(priceController.text.trim()),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _adjustMaterial(String id) async {
    String type = 'PURCHASE';
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('اصلاح موجودی'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'نوع تراکنش'),
              items: _txTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (value) => setDialogState(() => type = value ?? 'PURCHASE'),
            ),
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار')),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
          ],
        );
      }),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/inventory/$id/adjust', data: {
        'type': type,
        'quantity': double.tryParse(qtyController.text.trim()) ?? 0,
        if (noteController.text.trim().isNotEmpty) 'note': noteController.text.trim(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _deleteMaterial(String id) async {
    try {
      await ApiClient.instance.dio.delete('/inventory/$id');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _createMaterial, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _materials.isEmpty
            ? const Center(child: Text('هنوز ماده اولیه‌ای ثبت نشده است.'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _materials.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final material = _materials[index];
                  final current = double.tryParse(material['currentStock'].toString()) ?? 0;
                  final min = double.tryParse(material['minStock'].toString()) ?? 0;
                  final isLow = current <= min;
                  return Card(
                    color: isLow ? Colors.red.shade50 : null,
                    child: ListTile(
                      title: Text(material['name'] as String),
                      subtitle: Text('${FaNumbers.toFarsi(current.toStringAsFixed(0))} ${material['unit']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'adjust') _adjustMaterial(material['id'] as String);
                          if (value == 'delete') _deleteMaterial(material['id'] as String);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'adjust', child: Text('اصلاح موجودی')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
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
