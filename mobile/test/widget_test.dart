import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakery_manager/main.dart';
import 'package:bakery_manager/features/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  testWidgets('App boots and shows login screen when not authenticated',
      (WidgetTester tester) async {
    // کانال حافظه امن را mock می‌کنیم تا bootstrap در محیط تست کامل شود (بدون توکن ذخیره‌شده).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      storageChannel,
      (MethodCall call) async => null,
    );

    await tester.pumpWidget(const BakeryManagerApp());
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
