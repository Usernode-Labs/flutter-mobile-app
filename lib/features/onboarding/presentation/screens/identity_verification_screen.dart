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
      Log.d('IDENTITY_VERIFICATION', 'Starting zkPassport verification...');

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
        Log.d('IDENTITY_VERIFICATION', 'Identity verification completed successfully');
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
      Log.e('IDENTITY_VERIFICATION', 'Verification failed', e);
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  Future<void> _skipForLater() async {
    Log.d('IDENTITY_VERIFICATION', 'User skipped identity verification');

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
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_user,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

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

                  // Benefits card
                  _SectionCard(
                    title: 'Benefits',
                    icon: Icons.card_giftcard,
                    colorScheme: colorScheme,
                    theme: theme,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _BenefitItem(
                            icon: Icons.trending_up,
                            text: 'Increased reward multiplier',
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          _BenefitItem(
                            icon: Icons.widgets,
                            text: 'Access to block production feature',
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          _BenefitItem(
                            icon: Icons.security,
                            text: 'Enhanced account security',
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Privacy card
                  _SectionCard(
                    title: 'Privacy',
                    icon: Icons.shield,
                    colorScheme: colorScheme,
                    theme: theme,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your personal information is encrypted and will never be shared with anyone. We guarantee complete privacy.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.colorScheme,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _BenefitItem({
    required this.icon,
    required this.text,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
