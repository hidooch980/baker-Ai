/// تنظیمات محیطی اپلیکیشن. در بیلد: با --dart-define مقداردهی می‌شوند.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String appVersion = '0.1.0';
}
