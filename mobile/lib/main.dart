import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

void main() {
  runApp(const BakeryManagerApp());
}

class BakeryManagerApp extends StatelessWidget {
  const BakeryManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدیریت نانوایی',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        // در فاز بعد، GlobalMaterialLocalizations و flutter_localizations افزوده می‌شود.
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AppShell(),
    );
  }
}
