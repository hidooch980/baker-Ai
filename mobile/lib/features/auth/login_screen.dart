import 'package:flutter/material.dart';

/// صفحه ورود (شماره تلفن + رمز عبور). اتصال واقعی به POST /auth/login در فاز بعد افزوده می‌شود.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bakery_dining, size: 64),
                  const SizedBox(height: 8),
                  Text('مدیریت نانوایی', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'شماره تلفن'),
                    validator: (value) => (value == null || value.isEmpty) ? 'شماره تلفن را وارد کنید' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'رمز عبور'),
                    validator: (value) => (value == null || value.length < 6) ? 'رمز عبور باید حداقل ۶ کاراکتر باشد' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('ورود'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO(phase-2): اتصال واقعی به ApiClient.instance و ذخیره توکن.
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
    widget.onSuccess?.call();
  }
}
