import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'sync_engine.dart';

/// نتیجه ارسال: یا آنلاین انجام شد، یا در صف آفلاین ذخیره شد.
class SubmitResult {
  const SubmitResult.online(this.data) : queued = false;

  const SubmitResult.queued()
      : data = null,
        queued = true;

  final dynamic data;
  final bool queued;
}

/// آیا خطا ناشی از قطع شبکه یا در دسترس نبودن سرور است؟
bool isNetworkError(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return false;
  }
}

/// ابتدا تلاش می‌کند عملیات را آنلاین ارسال کند؛ در صورت خطای شبکه،
/// آن را برای همگام‌سازی بعدی در صف آفلاین ذخیره می‌کند.
/// خطاهای غیرشبکه‌ای (مثل خطای اعتبارسنجی سرور) همان لحظه پرتاب می‌شوند.
Future<SubmitResult> submitOrQueue({
  required String path,
  required String entity,
  required Map<String, dynamic> payload,
}) async {
  try {
    final response = await ApiClient.instance.dio.post(path, data: payload);
    return SubmitResult.online(response.data);
  } catch (e) {
    if (!isNetworkError(e)) rethrow;
    await SyncEngine.instance.enqueue(entity: entity, payload: payload);
    return const SubmitResult.queued();
  }
}
