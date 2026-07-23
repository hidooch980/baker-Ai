import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';

class AuthUser {
  AuthUser({required this.id, required this.fullName, required this.phone});

  final String id;
  final String fullName;
  final String phone;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}

/// وضعیت ورود کاربر را نگه می‌دارد و توکن‌ها را در حافظه امن ذخیره می‌کند.
class SessionController extends ChangeNotifier {
  SessionController._internal();
  static final SessionController instance = SessionController._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AuthUser? currentUser;
  bool isReady = false;

  Future<void> bootstrap() async {
    final token = await _storage.read(key: 'accessToken');
    final fullName = await _storage.read(key: 'userFullName');
    final phone = await _storage.read(key: 'userPhone');
    final id = await _storage.read(key: 'userId');
    if (token != null && id != null) {
      currentUser = AuthUser(id: id, fullName: fullName ?? '', phone: phone ?? '');
    }
    isReady = true;
    notifyListeners();
  }

  Future<String?> login(String phone, String password) async {
    try {
      final response = await ApiClient.instance.dio.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
      await _storage.write(key: 'refreshToken', value: data['refreshToken'] as String);
      final user = data['user'] as Map<String, dynamic>;
      await _storage.write(key: 'userId', value: user['id'] as String);
      await _storage.write(key: 'userFullName', value: user['fullName'] as String? ?? '');
      await _storage.write(key: 'userPhone', value: user['phone'] as String? ?? '');
      currentUser = AuthUser.fromJson(user);
      notifyListeners();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.dio.post('/auth/logout');
    } catch (_) {
      // خروج حتی در صورت خطای شبکه انجام می‌شود.
    }
    await _storage.deleteAll();
    currentUser = null;
    notifyListeners();
  }
}
