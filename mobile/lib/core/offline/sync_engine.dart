import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../network/api_error.dart';
import 'local_db.dart';

/// یک عملیات ثبت‌شده در صف آفلاین.
class QueuedOperation {
  QueuedOperation({
    required this.id,
    required this.entity,
    required this.operation,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.error,
  });

  final String id;
  final String entity;
  final String operation;
  final Map<String, dynamic> payload;
  final String status;
  final String? error;
  final DateTime createdAt;
}

/// موتور همگام‌سازی آفلاین:
/// عملیات ثبت‌شده در حالت آفلاین را در صف محلی نگه می‌دارد و با برقراری اتصال،
/// آن‌ها را به POST /sync/push می‌فرستد و داده‌های مرجع را از GET /sync/pull دریافت و کش می‌کند.
class SyncEngine extends ChangeNotifier {
  SyncEngine._internal();

  static final SyncEngine instance = SyncEngine._internal();

  bool _started = false;
  bool isSyncing = false;
  DateTime? lastSyncAt;
  String? lastSyncError;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// با ورود کاربر به اپ فراخوانی می‌شود: گوش دادن به تغییرات شبکه + یک همگام‌سازی اولیه.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await LocalDb.instance.open();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        unawaited(syncNow());
      }
    });
    unawaited(syncNow());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// شناسه یکتای این دستگاه برای ردیابی عملیات در سرور.
  Future<String> clientId() async {
    final db = await LocalDb.instance.open();
    final existing = LocalDb.instance.getValue(db, 'clientId');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    LocalDb.instance.setValue(db, 'clientId', id);
    return id;
  }

  /// افزودن یک عملیات CREATE به صف آفلاین.
  Future<void> enqueue({
    required String entity,
    required Map<String, dynamic> payload,
  }) async {
    final db = await LocalDb.instance.open();
    db.execute(
      'INSERT INTO sync_queue (id, entity, operation, payload, status, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        const Uuid().v4(),
        entity,
        'CREATE',
        jsonEncode(payload),
        'PENDING',
        DateTime.now().toIso8601String(),
      ],
    );
    notifyListeners();
  }

  /// همه آیتم‌های صف (جدیدترین اول).
  Future<List<QueuedOperation>> items() async {
    final db = await LocalDb.instance.open();
    final rows = db.select('SELECT * FROM sync_queue ORDER BY created_at DESC');
    return rows
        .map(
          (row) => QueuedOperation(
            id: row['id'] as String,
            entity: row['entity'] as String,
            operation: row['operation'] as String,
            payload: (jsonDecode(row['payload'] as String) as Map).cast<String, dynamic>(),
            status: row['status'] as String,
            error: row['error'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  /// تعداد عملیات در انتظار همگام‌سازی.
  Future<int> pendingCount() async {
    final db = await LocalDb.instance.open();
    final rows = db.select(
      "SELECT COUNT(*) AS item_count FROM sync_queue WHERE status IN ('PENDING', 'FAILED')",
    );
    return (rows.first['item_count'] as int?) ?? 0;
  }

  /// حذف یک آیتم از صف (مثلاً عملیات ناموفق یا دارای تعارض، پس از بررسی کاربر).
  Future<void> removeOperation(String id) async {
    final db = await LocalDb.instance.open();
    db.execute('DELETE FROM sync_queue WHERE id = ?', [id]);
    notifyListeners();
  }

  /// داده مرجع کش‌شده (مثل products، customers، paymentMethods) برای استفاده آفلاین در فرم‌ها.
  Future<List<Map<String, dynamic>>> cachedReference(String name) async {
    final db = await LocalDb.instance.open();
    final raw = LocalDb.instance.getValue(db, 'cache:$name');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  /// اجرای یک چرخه کامل همگام‌سازی: ابتدا push صف، سپس pull داده‌های مرجع.
  /// در صورت موفقیت null و در غیر این صورت متن خطا برمی‌گرداند.
  Future<String?> syncNow() async {
    if (isSyncing) return null;
    isSyncing = true;
    lastSyncError = null;
    notifyListeners();
    try {
      final db = await LocalDb.instance.open();
      final dio = ApiClient.instance.dio;

      // ۱) ارسال عملیات در انتظار
      final rows = db.select(
        "SELECT * FROM sync_queue WHERE status = 'PENDING' ORDER BY created_at ASC",
      );
      if (rows.isNotEmpty) {
        final operations = rows
            .map(
              (row) => <String, dynamic>{
                'clientOperationId': row['id'],
                'entity': row['entity'],
                'operation': row['operation'],
                'payload': jsonDecode(row['payload'] as String),
              },
            )
            .toList();
        final response = await dio.post('/sync/push', data: {
          'clientId': await clientId(),
          'operations': operations,
        });
        final results = (response.data as List)
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList();
        for (final result in results) {
          final opId = result['clientOperationId'] as String?;
          if (opId == null) continue;
          if (result['status'] == 'SYNCED') {
            db.execute('DELETE FROM sync_queue WHERE id = ?', [opId]);
          } else {
            db.execute(
              'UPDATE sync_queue SET status = ?, error = ? WHERE id = ?',
              [result['status'] ?? 'FAILED', result['errorMessage'], opId],
            );
          }
        }
      }

      // ۲) دریافت و کش داده‌های مرجع
      final since = LocalDb.instance.getValue(db, 'lastPulledAt');
      final pullResponse = await dio.get(
        '/sync/pull',
        queryParameters: since == null ? null : {'since': since},
      );
      final data = (pullResponse.data as Map).cast<String, dynamic>();
      final changes = data['changes'];
      if (changes is Map) {
        _mergeChanges(db, changes.cast<String, dynamic>());
      }
      final serverTime = data['serverTime'] as String?;
      if (serverTime != null) {
        LocalDb.instance.setValue(db, 'lastPulledAt', serverTime);
      }
      lastSyncAt = DateTime.now();
      return null;
    } catch (e) {
      lastSyncError = apiErrorMessage(e);
      return lastSyncError;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// تغییرات دریافتی را با کش قبلی بر اساس id ادغام می‌کند.
  void _mergeChanges(Database db, Map<String, dynamic> changes) {
    for (final entry in changes.entries) {
      final value = entry.value;
      if (value is! List || value.isEmpty) continue;
      final incoming = value.map((item) => (item as Map).cast<String, dynamic>()).toList();
      final key = 'cache:${entry.key}';
      final merged = <String, Map<String, dynamic>>{};
      final existingRaw = LocalDb.instance.getValue(db, key);
      if (existingRaw != null) {
        for (final item in (jsonDecode(existingRaw) as List)) {
          final map = (item as Map).cast<String, dynamic>();
          final id = map['id']?.toString();
          if (id != null) merged[id] = map;
        }
      }
      for (final item in incoming) {
        final id = item['id']?.toString();
        if (id != null) merged[id] = item;
      }
      LocalDb.instance.setValue(db, key, jsonEncode(merged.values.toList()));
    }
  }
}
