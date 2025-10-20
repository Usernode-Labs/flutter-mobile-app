import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// Profile Screen - User profile, identity, rewards, and settings
///
/// This screen will display:
/// - User info (account name, address)
/// - Identity verification status
/// - Rewards, tier, and points
/// - Account management
/// - App preferences and settings
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AccountMeta? _account;
  bool _isLoading = true;
  RpcEpochRewardsResp? _rewards;
  String? _privateKey;
  bool _showPrivateKey = false;

  // Tap detection for revealing crypto keys
  int _tapCount = 0;
  Timer? _tapTimer;
  bool _showCryptoKeys = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadRewards();
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final repo = await AccountsRepository.create();
    final account = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = account;
      _isLoading = false;
    });
    // Load private key after account is loaded
    if (account != null) {
      _loadPrivateKey(account.id);
    }
  }

  Future<void> _loadPrivateKey(String accountId) async {
    try {
      final repo = await AccountsRepository.create();
      final privateKey = await repo.getPrivateKey(accountId);
      if (!mounted) return;
      setState(() {
        _privateKey = privateKey;
      });
    } catch (e, st) {
      Log.e('PROFILE', 'Failed to load private key', e, st);
    }
  }

  Future<void> _loadRewards() async {
    try {
      Log.d('PROFILE', 'Loading epoch rewards');
      final rewards = await RustBackendService.instance.epochRewards();
      if (!mounted) return;
      setState(() {
        _rewards = rewards;
      });
      Log.d('PROFILE', 'Epoch rewards loaded: ${rewards != null}');
    } catch (e, st) {
      Log.e('PROFILE', 'Failed to load epoch rewards', e, st);
    }
  }

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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

  String _formatTokenAmount(BigInt amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount.toInt());
  }

  void _handleBottomTap() {
    _tapTimer?.cancel();

    setState(() {
      _tapCount++;

      if (_tapCount >= 3) {
        _showCryptoKeys = true;
        _tapCount = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Developer keys revealed'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Reset tap count after 3 seconds of inactivity
        _tapTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _tapCount = 0;
            });
          }
        });
      }
    });
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
        showNotifications: true,
      ),
      drawer: const AppDrawer(),
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
                            ? _accountColor(theme, _account!.address)
                                .withValues(alpha: 0.2)
                            : colorScheme.primaryContainer,
                        child: _account != null
                            ? Text(
                                'M',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color:
                                      _accountColor(theme, _account!.address),
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
                            Clipboard.setData(
                                ClipboardData(text: _account!.address));
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
                              _account != null
                                  ? _shortAddr(_account!.address)
                                  : '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy,
                              size: 16,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
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
                    child: _account != null && _account!.identityVerified
                        ? Column(
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
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _account!.identityVerifiedAt != null
                                    ? 'Verified on ${_formatDateTime(_account!.identityVerifiedAt!)}'
                                    : 'Your identity has been successfully verified',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (_account != null) {
                                      context.go(
                                          '/identity-verification?accountId=${_account!.id}');
                                    }
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Update Verification'),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Not Verified',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verify your identity to unlock additional features',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    if (_account != null) {
                                      context.go(
                                          '/identity-verification?accountId=${_account!.id}');
                                    }
                                  },
                                  icon:
                                      const Icon(Icons.verified_user, size: 18),
                                  label: const Text('Verify Identity'),
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
                                  'Epoch',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rewards != null ? '${_rewards!.epoch}' : '—',
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
                                  'Blocks Produced',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rewards != null
                                      ? '${_rewards!.producedInEpoch}'
                                      : '—',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Earned So Far',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rewards != null
                                      ? _formatTokenAmount(
                                          _rewards!.earnedSoFar)
                                      : '—',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Expected Total',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rewards != null
                                      ? _formatTokenAmount(
                                          _rewards!.expectedTotal)
                                      : '—',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_rewards != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Reward per Block:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                _formatTokenAmount(_rewards!.rewardPerBlock),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Slot Wins in Epoch:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                '${_rewards!.winsInEpoch}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Cryptographic Keys Card (hidden by default, revealed with 3 taps)
                if (_showCryptoKeys) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Cryptographic Keys',
                    icon: Icons.key,
                    colorScheme: colorScheme,
                    theme: theme,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Private Key
                          _KeyField(
                            label: 'Private Key',
                            value: _privateKey ?? 'Loading...',
                            isPrivate: true,
                            showValue: _showPrivateKey,
                            onToggleVisibility: () {
                              setState(() {
                                _showPrivateKey = !_showPrivateKey;
                              });
                            },
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),

                          // Public Key
                          _KeyField(
                            label: 'Public Key',
                            value: _account?.publicKey ?? '—',
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),

                          // Address
                          _KeyField(
                            label: 'Address',
                            value: _account?.address ?? '—',
                            colorScheme: colorScheme,
                            theme: theme,
                          ),

                          const SizedBox(height: 12),

                          // Hide button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showCryptoKeys = false;
                                  _showPrivateKey = false;
                                  _tapCount = 0;
                                });
                              },
                              icon: const Icon(Icons.visibility_off, size: 16),
                              label: const Text('Hide Keys'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Tap detection area (transparent, at bottom)
                GestureDetector(
                  onTap: _handleBottomTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 100,
                    color: Colors.transparent,
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

class _KeyField extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrivate;
  final bool showValue;
  final VoidCallback? onToggleVisibility;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _KeyField({
    required this.label,
    required this.value,
    this.isPrivate = false,
    this.showValue = true,
    this.onToggleVisibility,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = isPrivate && !showValue ? '•' * 64 : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),

        // Value container
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                displayValue,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPrivate && onToggleVisibility != null)
                    TextButton.icon(
                      onPressed: onToggleVisibility,
                      icon: Icon(
                        showValue ? Icons.visibility_off : Icons.visibility,
                        size: 14,
                      ),
                      label: Text(
                        showValue ? 'Hide' : 'Show',
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (isPrivate && onToggleVisibility != null)
                    const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () {
                      if (value != 'Loading...' && value != '—') {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$label copied to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text(
                      'Copy',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
