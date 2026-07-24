import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// دیتابیس محلی SQLite برای حالت آفلاین:
/// صف همگام‌سازی + وضعیت (کلید/مقدار) + کش داده‌های مرجع.
class LocalDb {
  LocalDb._internal();

  static final LocalDb instance = LocalDb._internal();

  Database? _db;

  /// دیتابیس را باز می‌کند (فقط بار اول؛ دفعات بعد همان اتصال قبلی برگردانده می‌شود).
  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = sqlite3.open(p.join(dir.path, 'bakery_local.db'));
    db.execute('''
CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  entity TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  error TEXT,
  created_at TEXT NOT NULL
);
''');
    db.execute('''
CREATE TABLE IF NOT EXISTS kv_state (
  key TEXT PRIMARY KEY,
  value TEXT
);
''');
    _db = db;
    return db;
  }

  String? getValue(Database db, String key) {
    final rows = db.select('SELECT value FROM kv_state WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void setValue(Database db, String key, String value) {
    db.execute(
      'INSERT INTO kv_state (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }
}
