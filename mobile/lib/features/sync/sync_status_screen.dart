import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/sync_engine.dart';

/// وضعیت همگام‌سازی: اتصال شبکه/سرور + صف آفلاین محلی.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  bool _hasNetwork = false;
  bool? _serverReachable;
  bool _isChecking = true;
  List<QueuedOperation> _queue = [];
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  static const Map<String, String> _entityLabels = {
    'Sale': 'فروش',
    'Expense': 'هزینه',
    'Production': 'تولید',
    'Attendance': 'حضور و غیاب',
  };

  static const Map<String, String> _statusLabels = {
    'PENDING': 'در انتظار',
    'FAILED': 'ناموفق',
    'CONFLICT': 'تعارض',
  };

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_onEngineChanged);
    _refresh();
    _subscription = Connectivity().onConnectivityChanged.listen((_) => _refresh());
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_onEngineChanged);
    _subscription?.cancel();
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_loadQueue());
  }

  Future<void> _loadQueue() async {
    final queue = await SyncEngine.instance.items();
    if (!mounted) return;
    setState(() => _queue = queue);
  }

  Future<void> _refresh() async {
    setState(() => _isChecking = true);
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    bool? serverReachable;
    if (hasNetwork) {
      try {
        await ApiClient.instance.dio.get('/health');
        serverReachable = true;
      } catch (_) {
        serverReachable = false;
      }
    }
    await _loadQueue();
    if (!mounted) return;
    setState(() {
      _hasNetwork = hasNetwork;
      _serverReachable = serverReachable;
      _isChecking = false;
    });
  }

  Future<void> _syncNow() async {
    final error = await SyncEngine.instance.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'همگام‌سازی با موفقیت انجام شد.')),
    );
    await _loadQueue();
  }

  Future<void> _removeItem(QueuedOperation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف از صف'),
        content: const Text('این عملیات از صف همگام‌سازی حذف شود؟ این کار قابل بازگشت نیست.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await SyncEngine.instance.removeOperation(item.id);
    await _loadQueue();
  }

  Future<void> _retryItem(QueuedOperation item) async {
    await SyncEngine.instance.retryOperation(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تلاش مجدد برای همگام‌سازی آغاز شد.')),
    );
    await _loadQueue();
  }

  @override
  Widget build(BuildContext context) {
    final engine = SyncEngine.instance;
    final pending = _queue.where((item) => item.status == 'PENDING').length;
    return Scaffold(
      appBar: AppBar(title: const Text('وضعیت همگام‌سازی')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isChecking || engine.isSyncing) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  _hasNetwork ? Icons.wifi : Icons.wifi_off,
                  color: _hasNetwork ? Colors.green : Colors.red,
                ),
                title: const Text('اتصال اینترنت'),
                subtitle: Text(_hasNetwork ? 'متصل' : 'قطع — ثبت‌ها به صورت محلی ذخیره می‌شوند'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  _serverReachable == true
                      ? Icons.cloud_done_outlined
                      : _serverReachable == false
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_queue_outlined,
                  color: _serverReachable == true
                      ? Colors.green
                      : _serverReachable == false
                          ? Colors.red
                          : Colors.grey,
                ),
                title: const Text('اتصال به سرور'),
                subtitle: Text(
                  _serverReachable == true
                      ? 'سرور در دسترس است'
                      : _serverReachable == false
                          ? 'سرور در دسترس نیست'
                          : 'نامشخص (بدون اینترنت)',
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  pending == 0 ? Icons.check_circle_outline : Icons.pending_actions,
                  color: pending == 0 ? Colors.green : Colors.orange,
                ),
                title: const Text('صف آفلاین'),
                subtitle: Text(
                  pending == 0
                      ? 'همه ثبت‌ها همگام هستند'
                      : '$pending عملیات در انتظار همگام‌سازی',
                ),
              ),
            ),
            if (engine.lastSyncAt != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'آخرین همگام‌سازی موفق: ${engine.lastSyncAt!.hour.toString().padLeft(2, '0')}:${engine.lastSyncAt!.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            if (engine.lastSyncError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  engine.lastSyncError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: engine.isSyncing ? null : _syncNow,
              icon: const Icon(Icons.sync),
              label: const Text('همگام‌سازی اکنون'),
            ),
            const SizedBox(height: 16),
            if (_queue.isNotEmpty) ...[
              Text('عملیات در صف', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._queue.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.status == 'PENDING'
                          ? Icons.schedule
                          : item.status == 'CONFLICT'
                              ? Icons.warning_amber_outlined
                              : Icons.error_outline,
                      color: item.status == 'PENDING' ? Colors.orange : Colors.red,
                    ),
                    title: Text(_entityLabels[item.entity] ?? item.entity),
                    subtitle: Text(
                      '${_statusLabels[item.status] ?? item.status} • ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}'
                      '${item.error != null ? '\n${item.error}' : ''}',
                    ),
                    trailing: item.status == 'PENDING'
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.status == 'FAILED')
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.blue),
                                  tooltip: 'تلاش مجدد',
                                  onPressed: () => _retryItem(item),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeItem(item),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ] else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'این اپلیکیشن آفلاین‌محور است: در صورت قطع اینترنت، ثبت فروش، هزینه و تولید به صورت محلی ذخیره می‌شود و با برقراری مجدد اتصال، به صورت خودکار با سرور همگام خواهد شد.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
