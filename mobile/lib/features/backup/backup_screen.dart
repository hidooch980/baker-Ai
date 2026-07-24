import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

const _backupStatusLabels = {
  'PENDING': 'در حال اجرا',
  'SUCCESS': 'موفق',
  'FAILED': 'ناموفق',
};

const _backupTypeLabels = {
  'DAILY': 'روزانه (خودکار)',
  'MANUAL': 'دستی',
};

/// صفحه پشتیبان‌گیری: فهرست نسخه‌های پشتیبان + اجرای پشتیبان‌گیری دستی.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> _backups = [];
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
      final response = await ApiClient.instance.dio.get('/backups');
      setState(() {
        _backups = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _runManualBackup() async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پشتیبان‌گیری دستی'),
        content: TextField(controller: noteController, decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('شروع پشتیبان‌گیری')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.post('/backups/manual', data: {
        if (noteController.text.trim().isNotEmpty) 'note': noteController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پشتیبان‌گیری انجام شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  String _sizeLabel(dynamic sizeBytes) {
    final size = double.tryParse(sizeBytes?.toString() ?? '') ?? 0;
    if (size <= 0) return '';
    return ' — ${(size / (1024 * 1024)).toStringAsFixed(2)} مگابایت';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبان‌گیری')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runManualBackup,
        icon: const Icon(Icons.backup_outlined),
        label: const Text('پشتیبان‌گیری دستی'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _backups.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), Center(child: Text('هنوز پشتیبانی گرفته نشده است.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _backups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final backup = _backups[index];
                            final status = backup['status'] as String? ?? '';
                            final startedAt = (backup['startedAt'] as String? ?? '').replaceFirst('T', ' ').split('.').first;
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  status == 'SUCCESS'
                                      ? Icons.check_circle_outline
                                      : status == 'FAILED'
                                          ? Icons.error_outline
                                          : Icons.hourglass_top_outlined,
                                  color: status == 'SUCCESS'
                                      ? Colors.green
                                      : status == 'FAILED'
                                          ? Colors.red
                                          : Colors.orange,
                                ),
                                title: Text('${_backupTypeLabels[backup['type']] ?? backup['type']} — ${_backupStatusLabels[status] ?? status}'),
                                subtitle: Text('$startedAt${_sizeLabel(backup['sizeBytes'])}'),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
