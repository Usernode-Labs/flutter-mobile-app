import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class AuthEmailScreen extends ConsumerStatefulWidget {
  const AuthEmailScreen({super.key});
  @override
  ConsumerState<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends ConsumerState<AuthEmailScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _controller.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      ref.read(authFlowProvider.notifier).setEmail(email);
      final res = await repo.checkEmail(email);
      if (res.exists && res.passwordSet) {
        if (mounted) context.go(AppRoutes.authPassword);
      } else {
        await repo.requestOtp(email);
        if (mounted) context.go(AppRoutes.authOtp);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(
                    labelText: l.authEmailLabel, errorText: _error),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l.authEmailContinue,
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
