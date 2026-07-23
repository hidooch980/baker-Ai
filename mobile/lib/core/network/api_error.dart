import 'package:dio/dio.dart';

/// استخراج پیام خطای قابل نمایش به کاربر از خطاهای شبکه/سرور.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
      return message.toString();
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'اتصال به سرور برقرار نشد. اتصال اینترنت را بررسی کنید.';
    }
    return 'خطایی رخ داد. لطفاً دوباره تلاش کنید.';
  }
  return 'خطایی رخ داد. لطفاً دوباره تلاش کنید.';
}
