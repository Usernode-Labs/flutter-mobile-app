// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/single_account_onboarding_screen.dart';

/// Profile Screen - User profile, identity, rewards, and settings
///
/// This screen will display:
/// - User info (account name, address)
/// - Identity verification status
/// - Rewards, tier, and points
/// - Account management
/// - App preferences and settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AccountMeta? _account;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final repo = await AccountsRepository.create();
    final account = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  Color _accountColor(ThemeData theme, String addr) {
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
    ];
    final idx = addr.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Profile',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Section
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                      radius: 48,
                      backgroundColor: _account != null
                          ? _accountColor(theme, _account!.address).withValues(alpha: 0.2)
                          : colorScheme.primaryContainer,
                      child: _account != null
                          ? Text(
                              'M',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: _accountColor(theme, _account!.address),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 48,
                              color: colorScheme.onPrimaryContainer,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'My Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        if (_account != null) {
                          Clipboard.setData(ClipboardData(text: _account!.address));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Address copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _account != null ? _shortAddr(_account!.address) : '—',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy,
                            size: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Identity & Verification Section
              _SectionCard(
                title: 'Identity & Verification',
                icon: Icons.verified_user,
                colorScheme: colorScheme,
                theme: theme,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Identity Verified',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your identity has been successfully verified',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rewards Section
              _SectionCard(
                title: 'Rewards & Tier',
                icon: Icons.card_giftcard,
                colorScheme: colorScheme,
                theme: theme,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tier',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏆 Basic',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Points',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '⭐ 1,234',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Multiplier: 2.5x',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Preferences Section
              _SectionCard(
                title: 'Preferences',
                icon: Icons.tune,
                colorScheme: colorScheme,
                theme: theme,
                child: Column(
                  children: [
                    _ListTileButton(
                      icon: Icons.dark_mode,
                      title: 'Theme',
                      trailing: 'System',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Theme'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.brightness_auto),
                                  title: const Text('System'),
                                  trailing: const Icon(Icons.check),
                                  onTap: () => Navigator.pop(ctx),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.light_mode),
                                  title: const Text('Light'),
                                  onTap: () => Navigator.pop(ctx),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.dark_mode),
                                  title: const Text('Dark'),
                                  onTap: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _ListTileButton(
                      icon: Icons.language,
                      title: 'Language',
                      trailing: 'English',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Language'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('English'),
                                  trailing: const Icon(Icons.check),
                                  onTap: () => Navigator.pop(ctx),
                                ),
                                ListTile(
                                  title: const Text('Français'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Language support coming soon')),
                                    );
                                  },
                                ),
                                ListTile(
                                  title: const Text('Español'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Language support coming soon')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _ListTileButton(
                      icon: Icons.attach_money,
                      title: 'Currency',
                      trailing: 'USD',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Currency'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('USD (\$)'),
                                  trailing: const Icon(Icons.check),
                                  onTap: () => Navigator.pop(ctx),
                                ),
                                ListTile(
                                  title: const Text('EUR (€)'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Currency support coming soon')),
                                    );
                                  },
                                ),
                                ListTile(
                                  title: const Text('GBP (£)'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Currency support coming soon')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Developer Section (for testing)
              _SectionCard(
                title: 'Developer',
                icon: Icons.code,
                colorScheme: colorScheme,
                theme: theme,
                child: Column(
                  children: [
                    _ListTileButton(
                      icon: Icons.delete_forever,
                      title: 'Delete Account',
                      onTap: _showDeleteAccountDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 48,
        ),
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your account and all associated data.',
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Make sure you have backed up your recovery phrase if you want to restore this account later.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final repo = await AccountsRepository.create();

      // Delete the active account
      if (_account != null) {
        await repo.deleteAccount(_account!.id);
      }

      if (!mounted) return;

      // Navigate directly to onboarding screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SingleAccountOnboardingScreen(),
        ),
        (_) => false,
      );

      // Show success message on the new screen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
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

class _ListTileButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _ListTileButton({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      trailing: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
