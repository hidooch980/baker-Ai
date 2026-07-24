import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/localization/fa_numbers.dart';

const _roleOptions = ['مدیر', 'فروشنده', 'خمیرگیر', 'چانه‌گیر', 'نانوا', 'حسابدار'];

const _shiftLabels = {
  'MORNING': 'صبح',
  'AFTERNOON': 'بعدازهر',
  'EVENING': 'عصر',
  'NIGHT': 'شب',
};

const _attendanceLabels = {
  'PRESENT': 'حاضر',
  'ABSENT': 'قایب',
  'LEAVE': 'مرخصی',
  'HALF_DAY': 'نیم‌روز',
  'OVERTIME': 'اضافه‌کاری',
};

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _employees = [];
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
      final response = await ApiClient.instance.dio.get('/employees');
      setState(() {
        _employees = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final fullNameController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController();
    String role = _roleOptions.first;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('کارمند جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
                TextField(controller: fullNameController, decoration: const InputDecoration(labelText: 'نام کامل')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'نقش'),
                  items: _roleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (value) => setDialogState(() => role = value ?? _roleOptions.first),
                ),
                const SizedBox(height: 8),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'تلفن (اختیاری)')),
                const SizedBox(height: 8),
                TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حقوق ماهیانه (اختیاری)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                if (fullNameController.text.trim().isEmpty) {
                  setDialogState(() => error = 'نام کامل را وارد کنید.');
                  return;
                }
                try {
                  await ApiClient.instance.dio.post('/employees', data: {
                    'fullName': fullNameController.text.trim(),
                    'role': role,
                    if (phoneController.text.trim().isNotEmpty) 'phone': phoneController.text.trim(),
                    if (salaryController.text.trim().isNotEmpty) 'baseSalary': double.tryParse(salaryController.text.trim()),
                  });
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
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('کارمندان')),
      floatingActionButton: FloatingActionButton(onPressed: _openCreateDialog, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _employees.isEmpty
                    ? const Center(child: Text('هنوز کارمندی ثبت نشده است.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _employees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final employee = _employees[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(employee['fullName'] as String? ?? ''),
                              subtitle: Text('${employee['role']}${employee['phone'] != null ? ' • ${employee['phone']}' : ''}'),
                              trailing: employee['baseSalary'] != null
                                  ? Text(FaNumbers.formatCurrency(double.tryParse(employee['baseSalary'].toString()) ?? 0))
                                  : null,
                              onTap: () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employeeId: employee['id'] as String)))
                                  .then((_) => _load()),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  Map<String, dynamic>? _employee;
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
      final response = await ApiClient.instance.dio.get('/employees/${widget.employeeId}');
      setState(() {
        _employee = response.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openAssignShift() async {
    String shift = 'MORNING';
    DateTime date = DateTime.now();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تخصیص شیفت'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              DropdownButtonFormField<String>(
                initialValue: shift,
                decoration: const InputDecoration(labelText: 'شیفت'),
                items: _shiftLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) => setDialogState(() => shift = value ?? 'MORNING'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('تاریخ: ${date.toIso8601String().split('T').first}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiClient.instance.dio.post('/employees/${widget.employeeId}/shifts', data: {
                    'shift': shift,
                    'date': date.toIso8601String(),
                  });
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

  Future<void> _openRecordAttendance() async {
    String status = 'PRESENT';
    DateTime date = DateTime.now();
    final overtimeController = TextEditingController();
    final noteController = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت حضور و عدم حضور'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'وضعیت'),
                  items: _attendanceLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (value) => setDialogState(() => status = value ?? 'PRESENT'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('تاریخ: ${date.toIso8601String().split('T').first}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                TextField(controller: overtimeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ساعت اضافه‌کاری (اختیاری)')),
                TextField(controller: noteController, decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiClient.instance.dio.post('/employees/${widget.employeeId}/attendance', data: {
                    'date': date.toIso8601String(),
                    'status': status,
                    if (overtimeController.text.trim().isNotEmpty) 'overtimeHours': double.tryParse(overtimeController.text.trim()),
                    if (noteController.text.trim().isNotEmpty) 'note': noteController.text.trim(),
                  });
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
    final employee = _employee;
    final shifts = (employee?['shifts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attendances = (employee?['attendances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(employee?['fullName'] as String? ?? 'کارمند')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('نقش: ${employee?['role'] ?? ''}'),
                              if (employee?['phone'] != null) Text('تلفن: ${employee?['phone']}'),
                              if (employee?['baseSalary'] != null)
                                Text('حقوق ماهیانه: ${FaNumbers.formatCurrency(double.tryParse(employee!['baseSalary'].toString()) ?? 0)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: ElevatedButton(onPressed: _openAssignShift, child: const Text('تخصیص شیفت'))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(onPressed: _openRecordAttendance, child: const Text('ثبت حضور'))),
                      ]),
                      const SizedBox(height: 16),
                      Text('شیفت‌های اخیر', style: Theme.of(context).textTheme.titleMedium),
                      if (shifts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('موردی ثبت نشده است.')),
                      ...shifts.map((s) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.schedule),
                            title: Text(_shiftLabels[s['shift']] ?? s['shift'].toString()),
                            trailing: Text((s['date'] as String? ?? '').split('T').first),
                          )),
                      const SizedBox(height: 16),
                      Text('حضور و عدم حضور اخیر', style: Theme.of(context).textTheme.titleMedium),
                      if (attendances.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('موردی ثبت نشده است.')),
                      ...attendances.map((a) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.event_available_outlined),
                            title: Text(_attendanceLabels[a['status']] ?? a['status'].toString()),
                            subtitle: (a['note'] as String?)?.isNotEmpty == true ? Text(a['note'] as String) : null,
                            trailing: Text((a['date'] as String? ?? '').split('T').first),
                          )),
                    ],
                  ),
                ),
    );
  }
}
