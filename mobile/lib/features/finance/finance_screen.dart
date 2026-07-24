import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';
import '../../core/offline/offline_submit.dart';
import '../../core/offline/sync_engine.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مالی'),
          bottom: const TabBar(tabs: [
            Tab(text: 'صندوق'),
            Tab(text: 'کارتخوان'),
            Tab(text: 'هزینه‌ها'),
          ]),
        ),
        body: const TabBarView(children: [
          _CashBoxTab(),
          _CardTransactionsTab(),
          _ExpensesTab(),
        ]),
      ),
    );
  }
}

const _cashTxLabels = {
  'RECEIPT': 'دریافت نقدی',
  'SALE_CASH': 'فروش نقدی',
  'DEBT_RECEIPT': 'دریافت بدهی',
  'EXPENSE': 'هزینه نقدی',
  'MANAGER_WITHDRAWAL': 'برداشت مدیر',
  'SUPPLIER_PAYMENT': 'پرداخت به تامین‌کننده',
};

class _CashBoxTab extends StatefulWidget {
  const _CashBoxTab();

  @override
  State<_CashBoxTab> createState() => _CashBoxTabState();
}

class _CashBoxTabState extends State<_CashBoxTab> {
  Map<String, dynamic>? _cashBox;
  bool _isLoading = true;
  bool _hasOpenCashBox = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.dio.get('/cash-box/open');
      setState(() {
        _cashBox = response.data as Map<String, dynamic>?;
        _hasOpenCashBox = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasOpenCashBox = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _openDay() async {
    final balanceController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('باز کردن صندوق امروز'),
        content: TextField(
          controller: balanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'موجودی اولیه'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('باز کردن')),
        ],
      ),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.dio.post('/cash-box/open', data: {
        'date': DateTime.now().toIso8601String(),
        'openingBalance': double.tryParse(balanceController.text.trim()) ?? 0,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _addTransaction() async {
    String type = 'RECEIPT';
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('تراکنش صندوق'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'نوع'),
                items: _cashTxLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) => setDialogState(() => type = value ?? 'RECEIPT'),
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
    if (result != true || _cashBox == null) return;
    try {
      await ApiClient.instance.dio.post('/cash-box/${_cashBox!['id']}/transactions', data: {
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

  Future<void> _closeDay() async {
    final balanceController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بستن روز'),
        content: TextField(
          controller: balanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'موجودی واقعی صندوق'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('بستن')),
        ],
      ),
    );
    if (result != true || _cashBox == null) return;
    try {
      await ApiClient.instance.dio.post('/cash-box/${_cashBox!['id']}/close', data: {
        'actualClosingBalance': double.tryParse(balanceController.text.trim()) ?? 0,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (!_hasOpenCashBox) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 40),
            const Center(child: Text('امروز هنوز صندوقی باز نشده است.')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _openDay, child: const Text('باز کردن صندوق')),
          ],
        ),
      );
    }
    final opening = double.tryParse(_cashBox?['openingBalance']?.toString() ?? '0') ?? 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('موجودی اولیه امروز', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(FaNumbers.formatCurrency(opening), style: Theme.of(context).textTheme.headlineSmall),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _addTransaction, icon: const Icon(Icons.add), label: const Text('تراکنش جدید')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _closeDay, icon: const Icon(Icons.lock_outline), label: const Text('بستن روز')),
        ],
      ),
    );
  }
}

class _CardTransactionsTab extends StatefulWidget {
  const _CardTransactionsTab();

  @override
  State<_CardTransactionsTab> createState() => _CardTransactionsTabState();
}

class _CardTransactionsTabState extends State<_CardTransactionsTab> {
  Map<String, dynamic>? _reconcile;
  bool _isLoading = false;
  String? _error;

  Future<void> _addCardTransaction() async {
    final amountController = TextEditingController();
    final terminalController = TextEditingController();
    final traceController = TextEditingController();
    final refController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تراکنش کارتخوان جدید'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلف')),
            TextField(controller: terminalController, decoration: const InputDecoration(labelText: 'شماره ترمینال (اختیاری)')),
            TextField(controller: traceController, decoration: const InputDecoration(labelText: 'شماره پیگیری (اختیاری)')),
            TextField(controller: refController, decoration: const InputDecoration(labelText: 'شماره مرجع (اختیاری)')),
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
      await ApiClient.instance.dio.post('/card-transactions', data: {
        'amount': double.tryParse(amountController.text.trim()) ?? 0,
        'occurredAt': DateTime.now().toIso8601String(),
        if (terminalController.text.trim().isNotEmpty) 'terminalId': terminalController.text.trim(),
        if (traceController.text.trim().isNotEmpty) 'traceNumber': traceController.text.trim(),
        if (refController.text.trim().isNotEmpty) 'refNumber': refController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت شد.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _checkReconcile() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      final response = await ApiClient.instance.dio.get('/card-transactions/reconcile', queryParameters: {'date': dateStr});
      setState(() {
        _reconcile = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {'result': response.data};
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(onPressed: _addCardTransaction, icon: const Icon(Icons.add), label: const Text('ثبت تراکنش کارتخوان')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _checkReconcile, icon: const Icon(Icons.fact_check_outlined), label: const Text('مطابقت با تاریخ')),
        const SizedBox(height: 16),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_reconcile != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _reconcile!.entries
                    .where((e) => e.value is! List)
                    .map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${e.key}: ${e.value}')))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab();

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  List<QueuedOperation> _queuedExpenses = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_onEngineChanged);
    _load();
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    unawaited(_loadQueuedExpenses());
  }

  Future<void> _loadQueuedExpenses() async {
    final all = await SyncEngine.instance.items();
    if (!mounted) return;
    setState(() => _queuedExpenses = all.where((item) => item.entity == 'Expense').toList());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadQueuedExpenses();
    if (!mounted) return;
    final dio = ApiClient.instance.dio;
    try {
      final results = await Future.wait([dio.get('/expenses'), dio.get('/expenses/categories')]);
      if (!mounted) return;
      setState(() {
        _expenses = (results[0].data as List).cast<Map<String, dynamic>>();
        _categories = (results[1].data as List).cast<Map<String, dynamic>>();
        _isOffline = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!isNetworkError(e)) {
        if (!mounted) return;
        setState(() {
          _error = apiErrorMessage(e);
          _isLoading = false;
        });
        return;
      }
      final cachedCategories = await SyncEngine.instance.cachedReference('expenseCategories');
      if (!mounted) return;
      setState(() {
        _categories = cachedCategories;
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _createExpense() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String? categoryId = _categories.isNotEmpty ? _categories.first['id'] as String : null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('هزینه جدید'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'عنوان')),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلف')),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'دسته'),
                items: _categories.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                onChanged: (value) => setDialogState(() => categoryId = value),
              ),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'شرح (اختیاری)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
          ],
        );
      }),
    );
    if (result != true || categoryId == null) return;
    final payload = <String, dynamic>{
      'title': titleController.text.trim(),
      'amount': double.tryParse(amountController.text.trim()) ?? 0,
      'categoryId': categoryId,
      if (descriptionController.text.trim().isNotEmpty) 'description': descriptionController.text.trim(),
    };
    try {
      final submitResult = await submitOrQueue(path: '/expenses', entity: 'Expense', payload: payload);
      if (!mounted) return;
      if (submitResult.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اینترنت در دسترس نیست؛ هزینه به صورت محلی ذخیره شد و پس از اتصال همگام می‌شود.')),
        );
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await ApiClient.instance.dio.delete('/expenses/$id');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _retryQueuedExpense(QueuedOperation item) async {
    await SyncEngine.instance.retryOperation(item.id);
    await _loadQueuedExpenses();
  }

  Future<void> _removeQueuedExpense(QueuedOperation item) async {
    await SyncEngine.instance.removeOperation(item.id);
    await _loadQueuedExpenses();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _createExpense, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_isOffline)
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.wifi_off, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('اتصال اینترنت برقرار نیست؛ دسته‌ها از حافظه محلی نمایش داده می‌شوند.'),
                    ),
                  ]),
                ),
              ),
            if (_queuedExpenses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('در صف همگام‌سازی', style: Theme.of(context).textTheme.titleMedium),
              ),
              ..._queuedExpenses.map((item) {
                final payload = item.payload;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      item.status == 'FAILED' ? Icons.error_outline : Icons.schedule,
                      color: item.status == 'FAILED' ? Colors.red : Colors.orange,
                    ),
                    title: Text(payload['title']?.toString() ?? ''),
                    subtitle: Text(
                      '${item.status == 'FAILED' ? 'ناموفق' : 'در انتظار همگام‌سازی'}'
                      '${item.error != null ? '\n${item.error}' : ''}',
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(FaNumbers.formatCurrency(double.tryParse(payload['amount'].toString()) ?? 0)),
                      if (item.status == 'FAILED')
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          tooltip: 'تلاش مجدد',
                          onPressed: () => _retryQueuedExpense(item),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeQueuedExpense(item),
                      ),
                    ]),
                  ),
                );
              }),
              const Divider(),
            ],
            if (_expenses.isEmpty && _queuedExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('هنوز هزینه‌ای ثبت نشده است.')),
              )
            else
              ..._expenses.map((expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(expense['title'] as String),
                        subtitle: Text((expense['date'] as String? ?? '').split('T').first),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(FaNumbers.formatCurrency(double.tryParse(expense['amount'].toString()) ?? 0)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteExpense(expense['id'] as String)),
                        ]),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
