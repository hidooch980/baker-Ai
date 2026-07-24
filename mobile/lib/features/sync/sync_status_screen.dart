import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

/// وضعیت همگام‌سازی: وضعیت اتصال شبکه و دسترسی به سرور.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  bool _hasNetwork = false;
  bool? _serverReachable;
  bool _isChecking = true;
  DateTime? _lastCheckedAt;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _check();
    _subscription = Connectivity().onConnectivityChanged.listen((_) => _check());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _isChecking = true);
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    bool? serverReachable;
    if (hasNetwork) {
      try {
        await ApiClient.instance.dio.get('/health');
        serverReachable = true;
      } catch (_) {
        try {
          await ApiClient.instance.dio.get('/notifications/unread-count');
          serverReachable = true;
        } catch (_) {
          serverReachable = false;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _hasNetwork = hasNetwork;
      _serverReachable = serverReachable;
      _isChecking = false;
      _lastCheckedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('وضعیت همگام‌سازی')),
      body: RefreshIndicator(
        onRefresh: _check,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isChecking) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  _hasNetwork ? Icons.wifi : Icons.wifi_off,
                  color: _hasNetwork ? Colors.green : Colors.red,
                ),
                title: const Text('اتصال اینترنت'),
                subtitle: Text(_hasNetwork ? 'متصل' : 'قطع — داده‌ها به صورت محلی ذخیره می‌شوند'),
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
            if (_lastCheckedAt != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'آخرین بررسی: ${_lastCheckedAt!.hour.toString().padLeft(2, '0')}:${_lastCheckedAt!.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: _check, icon: const Icon(Icons.refresh), label: const Text('بررسی مجدد')),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'این اپلیکیشن آفلاین‌محور است: در صورت قطع اینترنت، ثبت‌ها به صورت محلی ذخیره می‌شوند و با برقراری مجدد اتصال، به صورت خودکار با سرور همگام خواهند شد.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
