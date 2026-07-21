import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class AuthSetPasswordScreen extends ConsumerStatefulWidget {
  const AuthSetPasswordScreen({super.key});
  @override
  ConsumerState<AuthSetPasswordScreen> createState() =>
      _AuthSetPasswordScreenState();
}

class _AuthSetPasswordScreenState extends ConsumerState<AuthSetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final token = ref.read(authFlowProvider).setPasswordToken;
    if (token == null) {
      // Lost the single-use token; restart the OTP flow.
      context.go(AppRoutes.authOtp);
      return;
    }
    if (password.length < 8) {
      setState(() => _error = l.authErrorPasswordTooShort);
      return;
    }
    if (password != confirm) {
      setState(() => _error = l.authErrorPasswordMismatch);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await ref.read(authRepositoryProvider).setPassword(
            setPasswordToken: token,
            password: password,
            passwordConfirmation: confirm,
          );
      await ref.read(authStatusProvider.notifier).completeLogin(session);
      ref.read(authFlowProvider.notifier).reset();
      if (mounted) context.go(AppRoutes.splash);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.kind == AuthErrorKind.wrongToken) {
        // Expired/invalid set-password token: send back to request a new code.
        ref.read(authFlowProvider.notifier).setPasswordToken('');
        context.go(AppRoutes.authOtp);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: l.authSetPasswordLabel),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                    labelText: l.authConfirmPasswordLabel, errorText: _error),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l.authSetPasswordSubmit,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  isLoading: _submitting,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
