// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/theme/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/assets_provider.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/transaction_activity_provider.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/transaction_item.dart';
import 'package:crypto_mobile_app/core/utils/token_formatter.dart';

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
      await ref.read(walletAssetsProvider.notifier).refresh();
      await ref.read(transactionActivityProvider.notifier).refresh();

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
    context.push('/send');
  }

  void _handleReceiveTap() {
    context.push('/receive');
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

  String _shortHex(String hex, {int head = 8, int tail = 6}) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (h.length <= head + tail) return '0x$h';
    return '0x${h.substring(0, head)}…${h.substring(h.length - tail)}';
  }

  String _shortPk(String pk, {int head = 6, int tail = 4}) {
    final p = pk;
    if (p.length <= head + tail) return p;
    return '${p.substring(0, head)}…${p.substring(p.length - tail)}';
  }

  // Number formatting helpers
  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.##', 'en_US');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;

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
                SliverToBoxAdapter(
                  child: SizedBox(height: 40),
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
                  padding: EdgeInsets.all(kSpace8),
                  child: _buildFixedQuickActionsBar(theme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(ThemeData theme) {
    final assetsAsync = ref.watch(walletAssetsProvider);

    return FadeTransition(
      opacity: _balanceAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1), // Indigo-500
              Color(0xFF7C3AED), // Purple-600
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _balanceHidden ? Icons.visibility_off : Icons.visibility,
                      size: kIconSmall,
                    ),
                    color: Colors.white,
                    onPressed: _toggleBalanceVisibility,
                    tooltip: _balanceHidden ? 'Show balance' : 'Hide balance',
                  ),
                ],
              ),
              const SizedBox(height: kSpace4),

              // Balance amount
              assetsAsync.when(
                data: (assets) {
                  final totalBalance = assets.fold<BigInt>(BigInt.zero, (sum, a) => sum + a.totalBalance);
                  final tokenSymbol = assets.isNotEmpty ? assets.first.tokenSymbol : 'TKN';
                  final formattedBalance = '${_formatAmount(totalBalance.toDouble())} $tokenSymbol';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Token balance (primary)
                      Text(
                        _balanceHidden ? '••••••' : formattedBalance,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: kSpace8),
                      // Asset count (secondary)
                      if (!_balanceHidden)
                        Text(
                          '${assets.length} ${assets.length == 1 ? 'asset' : 'assets'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance skeleton
                    Container(
                      width: 200,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(kRadiusSmall),
                      ),
                    ),
                    const SizedBox(height: kSpace8),
                    // Asset count skeleton
                    Container(
                      width: 140,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(kRadiusSmall),
                      ),
                    ),
                  ],
                ),
                error: (e, _) => Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: kIconSmall,
                    ),
                    const SizedBox(width: kSpace8),
                    Text(
                      'Failed to load balance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
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
      elevation: 1,
      color: theme.colorScheme.surface,
      borderRadius: kBorderRadiusLarge,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: kSpace12),
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
    final assetsAsync = ref.watch(walletAssetsProvider);

    return assetsAsync.when(
      loading: () => _buildAssetsLoadingSkeleton(theme),
      error: (e, st) => _buildAssetsError(theme, e),
      data: (assets) {
        if (assets.isEmpty) {
          return _buildNoAssetsPlaceholder(theme);
        }
        return _buildAssetsGroupCard(theme, assets);
      },
    );
  }

  Widget _buildAssetsLoadingSkeleton(ThemeData theme) {
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
        children: [
          // Asset row skeletons
          ...List.generate(2, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: kSpace12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(kRadiusSmall),
                    ),
                  ),
                  const SizedBox(width: kSpace16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 16,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(kRadiusSmall),
                          ),
                        ),
                        const SizedBox(height: kSpace8),
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(kRadiusSmall),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(kRadiusSmall),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAssetsError(ThemeData theme, Object error) {
    return Container(
      padding: const EdgeInsets.all(kSpace16),
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
            size: kIconRegular,
          ),
          const SizedBox(height: kSpace8),
          Text(
            'Failed to load assets',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: kSpace8),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(walletAssetsProvider),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAssetsPlaceholder(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(kSpace24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: kSpace12),
          Text(
            'No assets yet',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: kSpace8),
          Text(
            'Receive tokens to see them here',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsGroupCard(ThemeData theme, List<AssetSummary> assets) {
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
      child: ListView.separated(
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
    );
  }

  Widget _buildAssetRow(ThemeData theme, AssetSummary asset) {
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
          child: Text(
            asset.tokenName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Token amount
        Text(
          '${_formatAmount(asset.totalBalance.toDouble())} ${asset.tokenSymbol}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
    final activityAsync = ref.watch(transactionActivityProvider);

    return activityAsync.when(
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
                onPressed: () => ref.invalidate(transactionActivityProvider),
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

        // Limit to 10 most recent transactions
        final displayedItems = items.take(10).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = displayedItems[index];
              final isLast = index == displayedItems.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: kSpace8),
                    child: _buildActivityRow(theme, item, index),
                  ),
                  if (!isLast)
                    Divider(
                      height: 0,
                      thickness: 0.5,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                ],
              );
            },
            childCount: displayedItems.length,
          ),
        );
      },
    );
  }

  Widget _buildActivityRow(
      ThemeData theme, TransactionItem transaction, int index) {
    // Determine icon and color based on type
    final isSent = transaction.type == TransactionType.sent;
    final isCoinbaseReward = transaction.type == TransactionType.coinbaseReward;
    final isGenesis = transaction.type == TransactionType.genesis;
    final isPending = transaction.status == TransactionStatus.pending;

    final iconColor = isSent
        ? theme.colorScheme.primary
        : (isCoinbaseReward || isGenesis)
            ? theme.colorScheme.secondary
            : theme.colorScheme.tertiary;
    final iconBgColor = isSent
        ? theme.colorScheme.primaryContainer
        : (isCoinbaseReward || isGenesis)
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.tertiaryContainer;

    // Format amounts
    String amountStr = '';
    if (transaction.amounts.isNotEmpty) {
      final firstAmount = transaction.amounts.first;
      final amountValue = firstAmount.amount.toInt();

      // Format the token amount
      final formatter = NumberFormat('#,##0', 'en_US');
      amountStr = formatter.format(amountValue);
      if (firstAmount.tokenId.isNotEmpty) {
        amountStr += ' ${TokenFormatter.formatTokenDisplay(firstAmount.tokenId)}';
      }
    }

    final shortId = _shortHex(transaction.id);

    return Row(
      children: [
        // Leading icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(kRadiusSmall),
          ),
          child: Icon(
            isSent
                ? Icons.arrow_upward
                : isCoinbaseReward
                    ? Icons.stars
                    : isGenesis
                        ? Icons.rocket_launch
                        : Icons.arrow_downward,
            color: iconColor,
            size: kIconSmall,
          ),
        ),
        const SizedBox(width: kSpace12),

        // Main content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with token amount
              Text(
                isSent
                    ? amountStr.isNotEmpty
                        ? 'Sent $amountStr'
                        : 'Sent'
                    : isCoinbaseReward
                        ? amountStr.isNotEmpty
                            ? 'Coinbase Reward $amountStr'
                            : 'Coinbase Reward'
                        : isGenesis
                            ? amountStr.isNotEmpty
                                ? 'Genesis Transaction $amountStr'
                                : 'Genesis Transaction'
                            : amountStr.isNotEmpty
                                ? 'Received $amountStr'
                                : 'Received',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: kSpace4),
              // Address line with "from:" or "to:" prefix - always show
              Text(
                transaction.recipientAddress != null
                    ? '${isSent ? 'to:' : 'from:'} ${_shortPk(transaction.recipientAddress!)}'
                    : _account != null
                        ? isSent
                            ? 'to: ${_shortAddr(_account!.address)}'
                            : 'from: ${_shortAddr(_account!.address)}'
                        : isSent
                            ? 'to: unknown'
                            : 'from: unknown',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: kSpace4),
              // Show fee only for sent transactions
              if (isSent && transaction.fee != null)
                Text(
                  'Fee: ${transaction.fee}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (isSent && transaction.fee != null) const SizedBox(height: kSpace4),
              // Transaction ID
              Text(
                'ID: $shortId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        // Trailing state
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace8,
            vertical: kSpace4,
          ),
          decoration: BoxDecoration(
            color: isPending
                ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                : theme.colorScheme.tertiary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(kRadiusFull),
          ),
          child: Text(
            isPending ? 'Pending' : 'Confirmed',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isPending
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
