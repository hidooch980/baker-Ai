import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

/// صفحه اعلان‌ها: فهرست هشدارها و اعلان‌های سیستم با امکان خوانده کردن.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _onlyUnread = false;
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
      final response = await ApiClient.instance.dio.get('/notifications', queryParameters: {
        if (_onlyUnread) 'onlyUnread': 'true',
      });
      setState(() {
        _notifications = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (notification['isRead'] == true) return;
    try {
      await ApiClient.instance.dio.patch('/notifications/${notification['id']}/read');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.instance.dio.patch('/notifications/read-all');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اعلان‌ها'),
        actions: [
          IconButton(
            tooltip: _onlyUnread ? 'نمایش همه' : 'فقط خوانده‌نشده‌ها',
            icon: Icon(_onlyUnread ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() => _onlyUnread = !_onlyUnread);
              _load();
            },
          ),
          IconButton(
            tooltip: 'خواندن همه',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _notifications.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), Center(child: Text('اعلانی وجود ندارد.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final isRead = notification['isRead'] == true;
                            final createdAt = (notification['createdAt'] as String? ?? '').split('T').first;
                            return Card(
                              color: isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              child: ListTile(
                                leading: Icon(
                                  isRead ? Icons.notifications_none : Icons.notifications_active_outlined,
                                  color: isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  notification['title'] as String? ?? '',
                                  style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                                ),
                                subtitle: Text('${notification['message'] ?? ''}\u200f — $createdAt'),
                                onTap: () => _markRead(notification),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
