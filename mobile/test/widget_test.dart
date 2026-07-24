import 'package:flutter_test/flutter_test.dart';
import 'package:bakery_manager/main.dart';
import 'package:bakery_manager/features/auth/login_screen.dart';

void main() {
  testWidgets('App boots and shows login screen when not authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const BakeryManagerApp());
    // اجازه بده bootstrap کامل شود و فریم بعدی رندر شود.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
