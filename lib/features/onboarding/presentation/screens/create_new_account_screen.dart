import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

class CreateNewAccountScreen extends ConsumerStatefulWidget {
  final String mnemonic;

  const CreateNewAccountScreen({
    super.key,
    required this.mnemonic,
  });

  @override
  ConsumerState<CreateNewAccountScreen> createState() =>
      _CreateNewAccountScreenState();
}

class _CreateNewAccountScreenState
    extends ConsumerState<CreateNewAccountScreen> {
  bool _ackSaved = false;
  bool _processing = false;

  Future<void> _createAccount() async {
    if (!_ackSaved || _processing) {
      Log.d('CREATE_ACCOUNT',
          'Cannot proceed - ackSaved: $_ackSaved, processing: $_processing');
      return;
    }

    Log.d('CREATE_ACCOUNT', 'Button pressed, starting account creation');
    setState(() => _processing = true);

    try {
      Log.d('CREATE_ACCOUNT', 'Creating AccountsRepository...');
      final repo = await AccountsRepository.create();
      Log.d('CREATE_ACCOUNT', 'Repository created successfully');

      Log.d('CREATE_ACCOUNT',
          'Calling importFromMnemonic with mnemonic length: ${widget.mnemonic.split(' ').length} words');
      final result = await repo.importFromMnemonic(
        name: 'My Account',
        mnemonic: widget.mnemonic,
      );
      Log.d('CREATE_ACCOUNT',
          'importFromMnemonic returned: ${result != null ? "success (id: ${result.id})" : "null"}');

      if (!mounted) {
        Log.d('CREATE_ACCOUNT', 'Widget unmounted after import, aborting');
        return;
      }

      // Check if import succeeded
      if (result == null) {
        Log.e('CREATE_ACCOUNT', 'Import failed - result is null');
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to create account: Invalid mnemonic or derivation error')),
        );
        return;
      }

      Log.d('CREATE_ACCOUNT',
          'Import successful, invalidating hasAnyAccountProvider...');
      // Invalidate the account provider so router sees the new account
      ref.invalidate(hasAnyAccountProvider);

      // Small delay to ensure provider refreshes before navigation
      await Future.delayed(const Duration(milliseconds: 150));

      // Check if widget is still mounted before navigation
      if (!mounted) {
        Log.d('CREATE_ACCOUNT',
            'Widget unmounted during delay, router likely already redirected');
        return;
      }

      // Start backend for newly created account
      Log.d('CREATE_ACCOUNT', 'Starting backend for new account...');
      final backendStarted =
          await RustBackendService.instance.startForActiveAccount();
      Log.d('CREATE_ACCOUNT', 'Backend start result: $backendStarted');

      if (!mounted) return;

      Log.d('CREATE_ACCOUNT', 'Provider invalidated, navigating to /main/home');
      // Navigate to home - router will handle redirect
      context.go('/main/home');
      Log.d('CREATE_ACCOUNT', 'Navigation triggered');
    } catch (e, stackTrace) {
      Log.e(
          'CREATE_ACCOUNT', 'Exception during account creation', e, stackTrace);
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Create New Account',
        showNotifications: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Write down your recovery phrase and store it safely. You\'ll need it to recover your account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Recovery Phrase',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _MnemonicGrid(mnemonic: widget.mnemonic),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                    value: _ackSaved,
                    onChanged: (v) => setState(() => _ackSaved = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I have safely stored my recovery phrase',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_ackSaved && !_processing) ? _createAccount : null,
                  child: _processing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MnemonicGrid extends StatelessWidget {
  final String mnemonic;
  const _MnemonicGrid({required this.mnemonic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words =
        mnemonic.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 360;
        final columns = isWide ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 6,
            childAspectRatio: 4.0,
          ),
          itemCount: words.length,
          itemBuilder: (_, i) {
            final idx = i + 1;
            final w = words[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$idx',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w,
                      style: theme.textTheme.titleMedium,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
