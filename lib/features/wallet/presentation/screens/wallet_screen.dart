// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/design/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
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
    // Prime UTXO provider
    // ignore: unused_result
    ref.read(walletUtxosProvider.future);
  }

  Future<void> _refreshWallet() async {
    try {
      // Refresh domain wallet state and local UTXOs
      await ref.read(walletProvider.notifier).refresh();
      await _walletService.refreshWalletData();
      await ref.read(walletUtxosProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to refresh wallet data')),
      );
    }
  }

  // Hex helpers
  String _bytesToHex(Iterable<int> bytes, {bool withPrefix = true}) {
    final sb = StringBuffer(withPrefix ? '0x' : '');
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  String _shortHex(String hex, {int head = 8, int tail = 6}) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (h.length <= head + tail) return '0x$h';
    return '0x${h.substring(0, head)}…${h.substring(h.length - tail)}';
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
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Wallet',
        showWalletAndProfile: false,
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshWallet,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(kSpace16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet balance summary (from provider)
                walletAsync.when(
                  data: (data) => AppCard.regular(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${data.balance.tokenAmount.toStringAsFixed(2)} ${data.balance.tokenSymbol}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => AppCard.regular(
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: kSpace12),
                        Expanded(
                          child: Text(
                            'Failed to load balance',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kSpace16),
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
        ...[
          // UTXOs via provider
          for (final widget in _buildUtxoSection(theme)) widget,
        ],
      ],
    );
  }

  List<Widget> _buildUtxoSection(ThemeData theme) {
    final utxosAsync = ref.watch(walletUtxosProvider);
    return [
      utxosAsync.when(
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace16),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        error: (e, _) => AppCard.regular(
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Text(
                  'Failed to load UTXOs',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return AppCard.regular(
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: kSpace12),
                  Expanded(
                    child: Text(
                      'No UTXOs found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: kSpace8),
                AppCard.regular(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.data_object,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: kIconSmall,
                        ),
                      ),
                      const SizedBox(width: kSpace16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (_) {
                                final fullHex = _bytesToHex(items[i].commitment.field0);
                                final short = _shortHex(fullHex);
                                return Text(
                                  'Commitment: $short',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: kSpace4),
                            Text(
                              'Owned UTXO',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '',
                      ),
                    ],
                  ),
                ),
              ]
            ],
          );
        },
      )
    ];
  }
}
