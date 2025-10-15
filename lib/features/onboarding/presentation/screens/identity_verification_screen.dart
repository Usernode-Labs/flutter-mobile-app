import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

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

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const AppAppBar(
          title: 'Identity Verification',
          automaticallyImplyLeading: false,
          showNotifications: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Verify Your Identity',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Verify your identity using zkPassport to unlock additional features and higher transaction limits.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Benefits list
                _BenefitItem(
                  icon: Icons.check_circle,
                  text: 'Increased transaction limits',
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _BenefitItem(
                  icon: Icons.check_circle,
                  text: 'Access to premium features',
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _BenefitItem(
                  icon: Icons.check_circle,
                  text: 'Enhanced account security',
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _BenefitItem(
                  icon: Icons.check_circle,
                  text: 'Priority customer support',
                  theme: theme,
                ),

                const Spacer(),

                // Info box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your personal information is encrypted and never shared without your consent.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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
              ],
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
          color: theme.colorScheme.primary,
          size: 20,
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
