import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Map<String, dynamic>> _payrolls = [];
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
      final response = await ApiClient.instance.dio.get('/payroll');
      setState(() {
        _payrolls = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openGenerate() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const GeneratePayrollScreen()));
    if (created == true) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> payroll) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PayrollDetailScreen(payrollId: payroll['id'] as String)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حقوق و دستمزد')),
      floatingActionButton: FloatingActionButton(onPressed: _openGenerate, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _payrolls.isEmpty
                    ? const Center(child: Text('هنوز فیش حقوقی صادر نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _payrolls.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final payroll = _payrolls[index];
                          final employee = payroll['employee'] as Map<String, dynamic>?;
                          final payments = (payroll['payments'] as List?) ?? [];
                          final paid = payments.fold<double>(0, (sum, p) => sum + (double.tryParse((p as Map)['amount'].toString()) ?? 0));
                          final net = double.tryParse(payroll['netAmount'].toString()) ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(employee?['fullName'] as String? ?? '—'),
                              subtitle: Text('${(payroll['periodStart'] as String? ?? '').split('T').first} تا ${(payroll['periodEnd'] as String? ?? '').split('T').first}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(FaNumbers.formatCurrency(net)),
                                  Text(
                                    paid >= net ? 'پرداخت‌شده' : 'باقی‌مانده: ${FaNumbers.formatCurrency(net - paid)}',
                                    style: TextStyle(fontSize: 12, color: paid >= net ? Colors.green : Colors.red),
                                  ),
                                ],
                              ),
                              onTap: () => _openDetail(payroll),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class GeneratePayrollScreen extends StatefulWidget {
  const GeneratePayrollScreen({super.key});

  @override
  State<GeneratePayrollScreen> createState() => _GeneratePayrollScreenState();
}

class _GeneratePayrollScreenState extends State<GeneratePayrollScreen> {
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _error;
  List<Map<String, dynamic>> _employees = [];

  String? _employeeId;
  DateTime _periodStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _periodEnd = DateTime.now();
  final _advancesController = TextEditingController();
  final _deductionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await ApiClient.instance.dio.get('/employees');
      setState(() {
        _employees = (response.data as List).cast<Map<String, dynamic>>();
        _isLoadingLookups = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoadingLookups = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _periodStart : _periodEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_employeeId == null) {
      setState(() => _error = 'کارمند را انتخاب کنید.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post('/payroll', data: {
        'employeeId': _employeeId,
        'periodStart': _periodStart.toIso8601String(),
        'periodEnd': _periodEnd.toIso8601String(),
        if (_advancesController.text.trim().isNotEmpty) 'advances': double.tryParse(_advancesController.text.trim()),
        if (_deductionsController.text.trim().isNotEmpty) 'deductions': double.tryParse(_deductionsController.text.trim()),
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
      appBar: AppBar(title: const Text('صدور فیش حقوق')),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                DropdownButtonFormField<String>(
                  value: _employeeId,
                  decoration: const InputDecoration(labelText: 'کارمند'),
                  items: _employees.map((e) => DropdownMenuItem<String>(value: e['id'] as String, child: Text(e['fullName'] as String))).toList(),
                  onChanged: (value) => setState(() => _employeeId = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text('از تاریخ: ${_periodStart.toIso8601String().split('T').first}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () => _pickDate(true),
                ),
                ListTile(
                  title: Text('تا تاریخ: ${_periodEnd.toIso8601String().split('T').first}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () => _pickDate(false),
                ),
                const SizedBox(height: 12),
                TextField(controller: _advancesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مساعده (اختیاری)')),
                const SizedBox(height: 12),
                TextField(controller: _deductionsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'کسورات (اختیاری)')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('صدور فیش'),
                  ),
                ),
              ],
            ),
    );
  }
}

class PayrollDetailScreen extends StatefulWidget {
  const PayrollDetailScreen({super.key, required this.payrollId});
  final String payrollId;

  @override
  State<PayrollDetailScreen> createState() => _PayrollDetailScreenState();
}

class _PayrollDetailScreenState extends State<PayrollDetailScreen> {
  Map<String, dynamic>? _payroll;
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
      final response = await ApiClient.instance.dio.get('/payroll/${widget.payrollId}');
      setState(() {
        _payroll = response.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openRecordPayment() async {
    final amountController = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت پرداخت'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار پرداخت')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(() => error = 'مقدار معتبر وارد کنید.');
                  return;
                }
                try {
                  await ApiClient.instance.dio.post('/payroll/${widget.payrollId}/payments', data: {'amount': amount});
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  setDialogState(() => error = apiErrorMessage(e));
                }
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final payroll = _payroll;
    final employee = payroll?['employee'] as Map<String, dynamic>?;
    final payments = (payroll?['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final paid = payments.fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount'].toString()) ?? 0));
    final net = payroll != null ? double.tryParse(payroll['netAmount'].toString()) ?? 0 : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('فیش حقوق')),
      floatingActionButton: FloatingActionButton(onPressed: _openRecordPayment, child: const Icon(Icons.payments_outlined)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(employee?['fullName'] as String? ?? '—', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('دوره: ${(payroll?['periodStart'] as String? ?? '').split('T').first} تا ${(payroll?['periodEnd'] as String? ?? '').split('T').first}'),
                            Text('پایه: ${FaNumbers.formatCurrency(double.tryParse(payroll?['baseAmount'].toString() ?? '0') ?? 0)}'),
                            Text('مساعده: ${FaNumbers.formatCurrency(double.tryParse(payroll?['advances'].toString() ?? '0') ?? 0)}'),
                            Text('کسورات: ${FaNumbers.formatCurrency(double.tryParse(payroll?['deductions'].toString() ?? '0') ?? 0)}'),
                            const Divider(),
                            Text('خالص پرداختی: ${FaNumbers.formatCurrency(net)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('پرداخت‌شده: ${FaNumbers.formatCurrency(paid)}'),
                            Text('باقی‌مانده: ${FaNumbers.formatCurrency(net - paid)}', style: TextStyle(color: (net - paid) > 0 ? Colors.red : Colors.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('تاریخچه پرداخت‌ها', style: Theme.of(context).textTheme.titleMedium),
                    if (payments.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('پرداختی ثبت نشده است.')),
                    ...payments.map((p) => ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(FaNumbers.formatCurrency(double.tryParse(p['amount'].toString()) ?? 0)),
                          trailing: Text((p['createdAt'] as String? ?? '').split('T').first),
                        )),
                  ],
                ),
    );
  }
}
