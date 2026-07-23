import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakery_manager/main.dart';

void main() {
  testWidgets('App boots and shows bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const BakeryManagerApp());
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
