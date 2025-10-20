import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  final String? accountId;

  const IdentityVerificationScreen({
    super.key,
    this.accountId,
  });

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  bool _processing = false;

  Future<void> _proceedWithVerification() async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      LoggingService.instance.debug('Starting zkPassport verification...',
          tag: 'IDENTITY_VERIFICATION');

      // TODO: Integrate with zkPassport SDK
      // For now, simulate verification process
      await Future.delayed(const Duration(seconds: 2));

      // Mock successful verification
      final verified = true;

      if (verified && widget.accountId != null) {
        final repo = await AccountsRepository.create();
        await repo.updateIdentityVerification(
          widget.accountId!,
          verified: true,
        );
        LoggingService.instance.debug(
            'Identity verification completed successfully',
            tag: 'IDENTITY_VERIFICATION');
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identity verification completed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Invalidate provider to update router state before navigation
      ref.invalidate(hasAnyAccountProvider);
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // Navigate to home
      context.go('/main/home');
    } catch (e) {
      LoggingService.instance
          .error('Verification failed', tag: 'IDENTITY_VERIFICATION', error: e);
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  Future<void> _skipForLater() async {
    LoggingService.instance.debug('User skipped identity verification',
        tag: 'IDENTITY_VERIFICATION');

    // Invalidate provider to update router state before navigation
    ref.invalidate(hasAnyAccountProvider);
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    context.go('/main/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const AppAppBar(
          title: 'Identity Verification',
          automaticallyImplyLeading: false,
          showNotifications: false,
          showNodeStatus: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Verify Your Identity',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Verify your identity using zkPassport to increase your reward multiplier and unlock block production features.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Benefits and Privacy in one simple card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BenefitItem(
                            icon: Icons.trending_up,
                            text: 'Increased reward multiplier',
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _BenefitItem(
                            icon: Icons.widgets,
                            text: 'Access to block production',
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _BenefitItem(
                            icon: Icons.security,
                            text: 'Enhanced account security',
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          Divider(color: colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your personal information is encrypted and never shared.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Proceed button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _processing ? null : _proceedWithVerification,
                      child: _processing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Proceed with Verification'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _processing ? null : _skipForLater,
                      child: const Text('Skip for Later'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;

  const _BenefitItem({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
