// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/design/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late WalletService _walletService;
  AccountMeta? _account;
  bool _balanceHidden = false;
  late AnimationController _balanceAnimationController;
  late Animation<double> _balanceAnimation;

  @override
  void initState() {
    super.initState();
    _walletService = WalletService.instance;
    _balanceAnimationController = AnimationController(
      duration: kAnimationNormal,
      vsync: this,
    );
    _balanceAnimation = CurvedAnimation(
      parent: _balanceAnimationController,
      curve: Curves.easeInOut,
    );
    _balanceAnimationController.forward();
    _loadActiveAccount();
  }

  @override
  void dispose() {
    _balanceAnimationController.dispose();
    super.dispose();
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
      await ref.read(walletProvider.notifier).refresh();
      await _walletService.refreshWalletData();
      await ref.read(walletUtxosProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Wallet refreshed'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusSmall),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to refresh wallet'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusSmall),
          ),
        ),
      );
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _balanceHidden = !_balanceHidden;
    });
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSmall),
        ),
      ),
    );
  }

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

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

  // Number formatting helpers
  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.##', 'en_US');
    return formatter.format(amount);
  }

  String _formatUSD(double usd) {
    final formatter = NumberFormat('\$#,##0.00', 'en_US');
    return formatter.format(usd);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    const double _qaBarHeight =
        88.0; // reserved height for fixed quick actions bar
    final double _bottomSpacer = keyboardOpen
        ? 0
        : (_qaBarHeight +
            kBottomNavigationBarHeight +
            kSpace16 +
            media.padding.bottom);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Wallet',
        showNotifications: true,
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshWallet,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Hero Balance Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace16,
                      kSpace16,
                      kSpace16,
                      kSpace12,
                    ),
                    child: _buildHeroBalanceCard(theme),
                  ),
                ),

                // Assets Section (Moved after Balance)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace16,
                      kSpace8,
                      kSpace16,
                      kSpace4,
                    ),
                    child: _buildAssetsSectionHeader(theme),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpace16),
                    child: _buildAssetsSection(theme),
                  ),
                ),

                // Quick Actions Grid

                // Recent Activity Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace16,
                      kSpace24,
                      kSpace16,
                      kSpace8,
                    ),
                    child: _buildActivitySectionHeader(theme),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kSpace16,
                    0,
                    kSpace16,
                    kSpace24,
                  ),
                  sliver: _buildActivitySection(theme),
                ),
              ],
            ),
          ),
          // Fixed Quick Actions bar overlay (hidden when keyboard is open)
          if (!keyboardOpen)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(0),
                  child: _buildFixedQuickActionsBar(theme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(ThemeData theme) {
    final walletAsync = ref.watch(walletProvider);

    return FadeTransition(
      opacity: _balanceAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(kRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(kSpace12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with "Total Balance" and hide button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _account != null
                        ? 'Total Balance (${_shortAddr(_account!.address)})'
                        : 'Total Balance',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _balanceHidden ? Icons.visibility_off : Icons.visibility,
                      size: kIconSmall,
                    ),
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.8),
                    onPressed: _toggleBalanceVisibility,
                    tooltip: _balanceHidden ? 'Show balance' : 'Hide balance',
                  ),
                ],
              ),
              const SizedBox(height: kSpace4),

              // Balance amount
              walletAsync.when(
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Token balance
                    Text(
                      _balanceHidden
                          ? '••••••'
                          : '${_formatAmount(data.balance.tokenAmount)} ${data.balance.tokenSymbol}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: kSpace8),
                    // USD value
                    if (!_balanceHidden)
                      Text(
                        '≈ ${_formatUSD(data.balance.usdValue)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance skeleton
                    Container(
                      width: 200,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(kRadiusSmall),
                      ),
                    ),
                    const SizedBox(height: kSpace8),
                    // USD skeleton
                    Container(
                      width: 140,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(kRadiusSmall),
                      ),
                    ),
                  ],
                ),
                error: (e, _) => Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: kIconSmall,
                    ),
                    const SizedBox(width: kSpace8),
                    Text(
                      'Failed to load balance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedQuickActionsBar(ThemeData theme) {
    return Material(
      elevation: 0,
      color: theme.colorScheme.surface,
      borderRadius: kBorderRadiusLarge,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace8),
        child: Row(
          children: [
            Expanded(
              child: AppActionButton(
                icon: Icons.arrow_upward,
                label: 'Send',
                color: theme.colorScheme.primary,
                size: AppActionButtonSize.compact,
                onTap: _handleSendTap,
              ),
            ),
            const SizedBox(width: kSpace8),
            Expanded(
              child: AppActionButton(
                icon: Icons.arrow_downward,
                label: 'Receive',
                color: theme.colorScheme.tertiary,
                size: AppActionButtonSize.compact,
                onTap: _handleReceiveTap,
              ),
            ),
            const SizedBox(width: kSpace8),
            Expanded(
              child: AppActionButton(
                icon: Icons.swap_horiz,
                label: 'Swap',
                color: theme.colorScheme.secondary,
                size: AppActionButtonSize.compact,
                onTap: () => _showComingSoon('Swap'),
              ),
            ),
            const SizedBox(width: kSpace8),
            Expanded(
              child: AppActionButton(
                icon: Icons.account_balance,
                label: 'Bridge',
                color: theme.colorScheme.primary,
                size: AppActionButtonSize.compact,
                onTap: () => _showComingSoon('Bridge'),
              ),
            ),
            const SizedBox(width: kSpace8),
            Expanded(
              child: AppActionButton(
                icon: Icons.more_horiz,
                label: 'More',
                color: theme.colorScheme.secondary,
                size: AppActionButtonSize.compact,
                onTap: () => _showComingSoon('More'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsSectionHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Assets',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton.icon(
          onPressed: () => _showComingSoon('View all assets'),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('View all'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace12,
              vertical: kSpace8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetsSection(ThemeData theme) {
    // Mock asset data
    final assets = [
      {
        'name': 'Token1',
        'symbol': 'TKN1',
        'amount': 1221.50,
        'value': 1834.25,
        'change': 2.5
      },
      {
        'name': 'Token2',
        'symbol': 'TKN2',
        'amount': 2002.00,
        'value': 3003.00,
        'change': -1.2
      },
    ];

    // Sort by USD value descending for most-relevant-first
    assets
        .sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    return _buildAssetsGroupCard(theme, assets);
  }

  Widget _buildAssetsGroupCard(
      ThemeData theme, List<Map<String, dynamic>> assets) {
    final totalValue =
        assets.fold<double>(0.0, (sum, a) => sum + (a['value'] as double));

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header with total and count
          Row(
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatUSD(totalValue),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: kSpace8),
              Text(
                '(${assets.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace12),
          // Asset rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: assets.length,
            itemBuilder: (context, index) =>
                _buildAssetRow(theme, assets[index]),
            separatorBuilder: (context, index) => Divider(
              height: kSpace16,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetRow(ThemeData theme, Map<String, dynamic> asset) {
    final isPositive = (asset['change'] as double) >= 0;

    return Row(
      children: [
        // Token icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(kRadiusSmall),
          ),
          child: Icon(
            Icons.monetization_on,
            color: theme.colorScheme.primary,
            size: kIconRegular,
          ),
        ),
        const SizedBox(width: kSpace16),

        // Token info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset['name'] as String,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: kSpace4),
              Text(
                '${_formatAmount(asset['amount'] as double)} ${asset['symbol']}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Value and change
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatUSD(asset['value'] as double),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: kSpace4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpace8,
                vertical: kSpace4,
              ),
              decoration: BoxDecoration(
                color: (isPositive
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.error)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: isPositive
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: kSpace4),
                  Text(
                    '${isPositive ? '+' : ''}${(asset['change'] as double).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isPositive
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivitySectionHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton.icon(
          onPressed: () => _showComingSoon('View all transactions'),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('View all'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace12,
              vertical: kSpace8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection(ThemeData theme) {
    final utxosAsync = ref.watch(walletUtxosProvider);

    return utxosAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpace32),
            child: Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: kSpace16),
                Text(
                  'Loading activity...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(kSpace24),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(kRadiusMedium),
            border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: kIconLarge,
              ),
              const SizedBox(height: kSpace12),
              Text(
                'Failed to load activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: kSpace8),
              Text(
                e.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpace16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(walletUtxosProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(kSpace32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(kRadiusMedium),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: kSpace16),
                  Text(
                    'No activity yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: kSpace8),
                  Text(
                    'Your transactions will appear here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : kSpace8),
                child: _buildActivityCard(theme, item, index),
              );
            },
            childCount: items.length,
          ),
        );
      },
    );
  }

  Widget _buildActivityCard(ThemeData theme, dynamic utxo, int index) {
    final fullHex = _bytesToHex(utxo.commitment.field0);
    final shortHex = _shortHex(fullHex);

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Transaction icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(kRadiusSmall),
            ),
            child: Icon(
              Icons.check_circle,
              color: theme.colorScheme.tertiary,
              size: kIconRegular,
            ),
          ),
          const SizedBox(width: kSpace16),

          // Transaction info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UTXO #${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: kSpace4),
                Text(
                  shortHex,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace8,
              vertical: kSpace4,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(kRadiusFull),
            ),
            child: Text(
              'Owned',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
