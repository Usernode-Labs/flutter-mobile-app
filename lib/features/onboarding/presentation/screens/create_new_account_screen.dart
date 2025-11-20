import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

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
      LoggingService.instance.trace(
          'Cannot proceed - ackSaved: $_ackSaved, processing: $_processing',
          tag: 'CREATE_ACCOUNT');
      return;
    }

    setState(() => _processing = true);

    try {
      LoggingService.instance
          .debug('Creating AccountsRepository...', tag: 'CREATE_ACCOUNT');
      final repo = await AccountsRepository.create();
      LoggingService.instance
          .debug('Repository created successfully', tag: 'CREATE_ACCOUNT');

      final result = await repo.importFromMnemonic(
        name: 'My Account',
        mnemonic: widget.mnemonic,
      );

      if (!mounted) {
        return;
      }

      // Check if import succeeded
      if (result == null) {
        LoggingService.instance
            .error('Import failed - result is null', tag: 'CREATE_ACCOUNT');
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to create account: Invalid mnemonic or derivation error')),
        );
        return;
      }

      LoggingService.instance
          .debug('Import successful, starting backend', tag: 'CREATE_ACCOUNT');

      // Start backend for new account
      try {
        await RustBackendService.instance.startForActiveAccount();
        LoggingService.instance
            .debug('Backend started successfully', tag: 'CREATE_ACCOUNT');
      } catch (e) {
        LoggingService.instance
            .error('Failed to start backend', tag: 'CREATE_ACCOUNT', error: e);
      }

      // Navigate to identity verification screen
      // Provider will be invalidated when user proceeds/skips verification
      // This prevents router redirect race condition
      if (!mounted) return;
      context.go('/identity-verification?accountId=${result.id}');
      LoggingService.instance
          .debug('Navigation triggered', tag: 'CREATE_ACCOUNT');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Exception during account creation',
          tag: 'CREATE_ACCOUNT', error: e, stackTrace: stackTrace);
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
        showNodeStatus: false,
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
