// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/design/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService _walletService;
  AccountMeta? _account;

  @override
  void initState() {
    super.initState();
    _walletService = WalletService.instance;
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = active;
    });

    if (_account != null && !RustBackendService.instance.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).backendStarting)),
      );
      await RustBackendService.instance.startForActiveAccount();
    }
  }

  Future<void> _refreshWallet() async {
    try {
      await _walletService.refreshWalletData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to refresh wallet data')),
      );
    }
  }

  void _handleSendTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SendScreen()),
    );
  }

  void _handleReceiveTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReceiveScreen()),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
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

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Wallet',
        showWalletAndProfile: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshWallet,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(kSpace16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Header
                if (_account != null) _buildAccountHeader(theme),
                if (_account != null) const SizedBox(height: kSpace24),

                // Quick Actions
                _buildQuickActions(theme),
                const SizedBox(height: kSpace32),

                // Balances Section
                _buildBalancesSection(theme),
                const SizedBox(height: kSpace24),

                // Activity Section
                _buildActivitySection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountHeader(ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _accountColor(theme, _account!.address)
              .withValues(alpha: kAlphaMedium),
          foregroundColor: _accountColor(theme, _account!.address),
          child: const Icon(Icons.account_circle, size: kIconSmall),
        ),
        const SizedBox(width: kSpace12),
        Expanded(
          child: Text(
            _shortAddr(_account!.address),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (FeatureFlags.on('wallet.send'))
          Expanded(
            child: AppActionButton(
              icon: Icons.arrow_upward,
              label: 'Send',
              color: theme.colorScheme.primary,
              onTap: _handleSendTap,
            ),
          ),
        if (FeatureFlags.on('wallet.receive'))
          Expanded(
            child: AppActionButton(
              icon: Icons.arrow_downward,
              label: 'Receive',
              color: theme.colorScheme.tertiary,
              onTap: _handleReceiveTap,
            ),
          ),
        Expanded(
          child: AppActionButton(
            icon: Icons.swap_horiz,
            label: 'Swap',
            color: theme.colorScheme.secondary,
            onTap: () => _showComingSoon('Swap'),
          ),
        ),
        if (FeatureFlags.on('wallet.bridge'))
          Expanded(
            child: AppActionButton(
              icon: Icons.account_balance,
              label: 'Bridge',
              color: theme.colorScheme.primary,
              onTap: () => _showComingSoon('Bridge'),
            ),
          ),
      ],
    );
  }

  Widget _buildBalancesSection(ThemeData theme) {
    // Mock data
    final holdings = [
      {'name': 'Token1', 'symbol': 'TKN', 'amount': 1221},
      {'name': 'Token2', 'symbol': 'TKN', 'amount': 2002},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balances',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: kSpace12),
        AppCard.regular(
          child: Column(
            children: [
              for (int i = 0; i < holdings.length; i++) ...[
                if (i > 0) const SizedBox(height: kSpace12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: kAlphaStrong),
                      child: Icon(
                        Icons.monetization_on_outlined,
                        color: theme.colorScheme.onSurface,
                        size: kIconSmall,
                      ),
                    ),
                    const SizedBox(width: kSpace16),
                    Expanded(
                      child: Text(
                        holdings[i]['name'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${holdings[i]['amount']} ${holdings[i]['symbol']}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection(ThemeData theme) {
    // Mock data
    final activities = [
      {
        'type': 'send',
        'title': 'Send',
        'date': 'August 19, 2025',
        'amount': '-1.0 Tokens',
        'icon': Icons.north_east,
      },
      {
        'type': 'receive',
        'title': 'Received',
        'date': 'August 19, 2025',
        'amount': '+1.0 Tokens',
        'icon': Icons.south_west,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: kSpace12),
        for (int i = 0; i < activities.length; i++) ...[
          if (i > 0) const SizedBox(height: kSpace8),
          AppCard.regular(
            onTap: () {},
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    activities[i]['icon'] as IconData,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: kIconSmall,
                  ),
                ),
                const SizedBox(width: kSpace16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activities[i]['title'] as String,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: kSpace4),
                      Text(
                        activities[i]['date'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  activities[i]['amount'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
