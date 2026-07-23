import 'package:flutter/material.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
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
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

/// در ابتدا وضعیت ورود را بارگذاری می‌کند و بر اساس وجود توکن، صفحه ورود یا پوسته اصلی را نمایش می‌دهد.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SessionController _session = SessionController.instance;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _session.bootstrap();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!_session.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session.currentUser == null) {
      return LoginScreen(onSuccess: () => setState(() {}));
    }
    return const AppShell();
  }
}
