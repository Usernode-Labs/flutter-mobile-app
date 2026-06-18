import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/providers/wallet_provider.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/features/dapps/models/dapp_item.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

final _log = LoggingService.instance.withTag('usernode/WalletScreen');

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Timer? _refreshTimer;
  final _scrollFraction = ValueNotifier<double>(0.0);
  String _address = 'Loading...';
  final _appSleepService = AppSleepService.instance;

  @override
  void initState() {
    super.initState();
    _appSleepService.addListener(_handleAppSleepChanged);
    _startAutoRefresh();

    // Resolve address when accounts provider loads or changes.
    ref.listenManual(accountsProvider, (_, __) => _resolveAddress());

    // React to tab changes — refresh when wallet tab becomes active.
    ref.listenManual(currentHomeTabProvider, (previous, next) {
      if (next == HomeTab.wallet && previous != HomeTab.wallet) {
        _log.debug('Switching to wallet tab - triggering refresh');
        _onRefresh();
      }
    });
  }

  Future<void> _resolveAddress() async {
    final accounts = ref.read(accountsProvider);
    final repo = accounts.valueOrNull;
    if (repo == null) return;
    final active = await repo.getActive();
    if (mounted && active != null) {
      setState(() => _address = active.address);
    }
  }

  @override
  void dispose() {
    _appSleepService.removeListener(_handleAppSleepChanged);
    _scrollFraction.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    if (_appSleepService.isSleeping) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_appSleepService.isSleeping) return;
      // Only refresh if currently on wallet tab (index 1)
      final currentTab = ref.read(currentHomeTabProvider);
      if (currentTab == HomeTab.wallet) {
        await Future.wait([
          ref.read(walletProvider.notifier).silentRefresh(),
          ref.read(nodeStatusProvider.notifier).silentRefresh(),
        ]);
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(walletProvider.notifier).silentRefresh(),
      ref.read(nodeStatusProvider.notifier).silentRefresh(),
    ]);

    _startAutoRefresh();
  }

  void _handleAppSleepChanged() {
    if (!mounted) return;
    if (_appSleepService.isSleeping) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }

    _startAutoRefresh();
    unawaited(_onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final walletState = ref.watch(walletProvider);
    final nodeStatus = ref.watch(nodeStatusProvider);

    // Profile pill mirrors the Challenges tab: show the player's points when
    // available (breakdown wins; ranking is the fallback), else "Profile".
    final points = ref.watch(
            breakdownProvider.select((s) => s.valueOrNull?.totalPoints)) ??
        ref.watch(
          rankingProvider.select((s) => s.valueOrNull?.totalPoints),
        );
    final profileLabel = points != null
        ? '${NumberFormat('#,##0').format(points)} pts'
        : 'Profile';

    return Scaffold(
      // No backgroundColor override → DS scaffold grey (surface), shared by all
      // top-level tab roots. Nested pages (Profile, etc.) use white surfaces.
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TopStatusAppBar.large(
              title: l10n.navWallet,
              profileLabel: profileLabel,
              nodeStatus: ref.watch(topStatusNodeStatusProvider),
              onProfilePressed: () => context.push(AppRoutes.profile),
              onNodePressed: () => context.push(AppRoutes.mainNode),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                spacing.space16,
                0,
                spacing.space16,
                spacing.space12,
              ),
              sliver: SliverToBoxAdapter(
                child: AppCard(
                  color: theme.colorScheme.surfaceContainerLowest,
                  padding: EdgeInsets.all(spacing.space16),
                  child: _BalanceSection(
                    walletState: walletState,
                    nodeStatus: nodeStatus,
                    l10n: l10n,
                    onSend: () => context.push(AppRoutes.walletSend),
                    onScan: () => context.push(AppRoutes.walletScan),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                spacing.space16,
                0,
                spacing.space16,
                spacing.space12,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildAddressRow(theme, l10n, spacing),
              ),
            ),
            ..._buildSurfaceSlivers(walletState, l10n, theme, spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(
    ThemeData theme,
    AppLocalizations l10n,
    AppSpacing spacing,
  ) {
    final colors = theme.colorScheme;
    final sizing = theme.extension<AppSizing>()!;
    final textTheme = theme.textTheme;

    return AppCard(
      color: colors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      child: Row(
        children: [
          IconBadge(
            icon: Symbols.account_balance_wallet_sharp,
            size: sizing.iconContainerSmall,
          ),
          SizedBox(width: spacing.space16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.walletMyAddress,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: spacing.space4),
                Text(
                  _address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    fontFamily: kMonoFontFamily,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.space8),
          IconButton(
            tooltip: l10n.walletMyAddress,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _address));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.walletAddressCopied)),
              );
            },
            icon: const Icon(Symbols.content_copy_sharp),
          ),
          IconButton(
            tooltip: l10n.walletReceive,
            onPressed: _address.isEmpty || _address == 'Loading...'
                ? null
                : _showReceiveSheet,
            icon: const Icon(Symbols.qr_code_2_sharp),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet showing the active address as a scannable QR for receiving,
  /// with the address text and a copy action.
  void _showReceiveSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        final spacing = theme.extension<AppSpacing>()!;
        final radii = theme.extension<AppRadii>()!;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              spacing.space24,
              0,
              spacing.space24,
              spacing.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.walletReceive,
                  style: theme.textTheme.titleMedium,
                ),
                SizedBox(height: spacing.space16),
                Container(
                  padding: EdgeInsets.all(spacing.space16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: radii.borderRadiusLarge,
                  ),
                  child: QrImageView(
                    data: _address,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: colors.surfaceContainerLowest,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: colors.onSurface,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                SizedBox(height: spacing.space16),
                Text(
                  _address,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: kMonoFontFamily,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: spacing.space16),
                Button(
                  variant: ButtonVariant.tonal,
                  label: l10n.walletCopyAddress,
                  leadingIcon: const Icon(Symbols.content_copy_sharp),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _address));
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.walletAddressCopied)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCachedDataBanner(
    AsyncValue walletState,
    ThemeData theme,
    AppSpacing spacing,
  ) {
    return walletState.when(
      data: (state) {
        final hasExplorerData =
            state.recent.any((tx) => tx.dataSource != DataSource.local);
        final hasOnlyCachedData = state.recent.every((tx) =>
            tx.dataSource == DataSource.cached ||
            tx.dataSource == DataSource.local);

        if (hasExplorerData && hasOnlyCachedData && state.recent.isNotEmpty) {
          final semantic = theme.extension<AppSemanticColors>()!;
          final sizing = theme.extension<AppSizing>()!;
          final radii = theme.extension<AppRadii>()!;

          return Container(
            margin: EdgeInsets.only(bottom: spacing.space8),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.space12,
              vertical: spacing.space8,
            ),
            decoration: BoxDecoration(
              color: semantic.warning.colorContainer,
              borderRadius: radii.borderRadiusSmall,
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.warning_amber_sharp,
                  color: semantic.warning.color,
                  size: sizing.iconXSmall,
                ),
                SizedBox(width: spacing.space8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).walletExplorerUnavailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.warning.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<Widget> _buildSurfaceSlivers(
    AsyncValue walletState,
    AppLocalizations l10n,
    ThemeData theme,
    AppSpacing spacing,
  ) {
    return [
      // Cached-data warning sits above the activity card (not in the design
      // board, but kept for correctness). Collapses to zero height when N/A.
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        sliver: SliverToBoxAdapter(
          child: _buildCachedDataBanner(walletState, theme, spacing),
        ),
      ),
      ...walletState.when(
        loading: () => [
          _recentActivityCardSliver(
            theme,
            l10n,
            spacing,
            child: ShimmerHost(
              child: Column(
                children: List.generate(4, (_) => const ShimmerListTile()),
              ),
            ),
          ),
        ],
        error: (_, __) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: FullPageErrorState(
              message: l10n.walletTransactionsError,
            ),
          ),
        ],
        data: (state) {
          if (state.recent.isEmpty) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: l10n.walletNoRecentActivity,
                  subtitle: l10n.walletNoRecentActivitySubtitle,
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Button(
                        variant: ButtonVariant.primary,
                        label: l10n.walletEmptyStateSendAction,
                        onTap: () => context.push(AppRoutes.walletSend),
                      ),
                      SizedBox(width: spacing.space8),
                      Button(
                        variant: ButtonVariant.tonal,
                        label: l10n.walletScan,
                        onTap: () => context.push(AppRoutes.walletScan),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          }
          return [
            _recentActivityCardSliver(
              theme,
              l10n,
              spacing,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tx in state.recent) _TransactionTile(tx),
                ],
              ),
            ),
          ];
        },
      ),
    ];
  }

  /// Recent Activity wrapped in a titled [AppCard] (matches the wallet
  /// prototype): the section title lives inside the card, above [child].
  Widget _recentActivityCardSliver(
    ThemeData theme,
    AppLocalizations l10n,
    AppSpacing spacing, {
    required Widget child,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space32,
      ),
      sliver: SliverToBoxAdapter(
        child: AppCard(
          color: theme.colorScheme.surfaceContainerLowest,
          padding: EdgeInsets.symmetric(vertical: spacing.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space8,
                ),
                child: Text(
                  l10n.walletRecentActivity,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// --- Extracted Widgets ---

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.walletState,
    required this.nodeStatus,
    required this.l10n,
    required this.onSend,
    required this.onScan,
  });

  final AsyncValue walletState;
  final AsyncValue nodeStatus;
  final AppLocalizations l10n;
  final VoidCallback onSend;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final syncStatus = nodeStatus.valueOrNull?.syncStatus;
    final showSyncMessage = syncStatus == null || !syncStatus.isSynced;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.walletTokenBalance,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.space16),
        walletState.when(
          data: (state) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: state.balance.tokenAmount),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              NumberFormat('#,##0').format(value.toInt()),
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontFamily: kMonoFontFamily),
            ),
          ),
          loading: () => const ShimmerBlock(width: 180, height: 36),
          error: (_, __) => Text(
            l10n.commonNoValuePlaceholder,
            style: theme.textTheme.displaySmall
                ?.copyWith(fontFamily: kMonoFontFamily),
          ),
        ),
        // Single status line under the balance: while the node is catching up
        // it reads "Sync in progress…"; once synced it shows the last-checked
        // time. The two never stack.
        Builder(
          builder: (context) {
            final statusStyle = theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            );
            if (showSyncMessage && nodeStatus.hasValue) {
              return Padding(
                padding: EdgeInsets.only(top: spacing.space4),
                child: Text(l10n.walletSyncInProgress, style: statusStyle),
              );
            }
            final lastChecked = walletState.valueOrNull?.balance.lastUpdated;
            if (lastChecked != null) {
              return Padding(
                padding: EdgeInsets.only(top: spacing.space4),
                child: Text(
                  l10n.commonLastCheckedAt(
                    walletState.value!.balance.lastUpdatedText,
                  ),
                  style: statusStyle,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        SizedBox(height: spacing.space16),
        Row(
          children: [
            Expanded(
              child: Button(
                label: l10n.walletSend,
                variant: ButtonVariant.primary,
                leadingIcon: const Icon(Symbols.north_east_sharp),
                onTap: onSend,
              ),
            ),
            SizedBox(width: spacing.space8),
            Expanded(
              child: Button(
                label: l10n.walletScan,
                variant: ButtonVariant.tonal,
                leadingIcon: const Icon(Symbols.qr_code_scanner_sharp),
                onTap: onScan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile(this.transaction);
  final TransactionModel transaction;

  String _displayDetails() {
    switch (transaction.type) {
      case TransactionType.send:
        return transaction.subtitle.startsWith('To:')
            ? transaction.subtitle
            : transaction.shortHash;
      case TransactionType.receive:
        return transaction.subtitle.startsWith('From:')
            ? transaction.subtitle
            : transaction.shortHash;
      case TransactionType.reward:
        const prefix = 'reward:';
        final id = transaction.id;
        final normalized =
            id.startsWith(prefix) ? id.substring(prefix.length) : id;
        return Utils.shortenID(normalized, head: 8, tail: 8);
      case TransactionType.genesis:
      case TransactionType.fee:
        return transaction.shortHash;
    }
  }

  /// Match this transaction's counterparty against the dapps directory.
  /// Returns null for non-transfer types or when the counterparty isn't
  /// a registered dapp.
  DappItem? _matchDapp(Map<String, DappItem> byPubkey) {
    if (byPubkey.isEmpty) return null;
    if (transaction.type != TransactionType.send &&
        transaction.type != TransactionType.receive) {
      return null;
    }
    final addr = transaction.counterpartyAddress;
    if (addr == null || addr.isEmpty) return null;
    return byPubkey[addr];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final isPending = transaction.status == TransactionStatus.pending;

    final dapp = _matchDapp(ref.watch(dappByPubkeyProvider));
    final isDappTx = dapp != null;

    String baseTitle = transaction.title;
    if (isDappTx) {
      switch (transaction.type) {
        case TransactionType.send:
          // Replace generic "Sending" / "Sent" with a dapp-aware variant
          // so users can tell at a glance which transactions are dapp
          // interactions vs. plain peer transfers.
          baseTitle =
              isPending ? 'Sending to ${dapp.name}' : 'Sent to ${dapp.name}';
          break;
        case TransactionType.receive:
          baseTitle = isPending
              ? 'Receiving from ${dapp.name}'
              : 'Received from ${dapp.name}';
          break;
        case TransactionType.reward:
        case TransactionType.genesis:
        case TransactionType.fee:
          break;
      }
    }

    final titleText =
        isPending ? '$baseTitle · ${transaction.statusText}' : baseTitle;

    // Use the apps grid icon to visually distinguish dapp activity from
    // person-to-person transfers (which keep their directional arrow).
    final tileIcon = isPending && transaction.type == TransactionType.send
        ? Symbols.hourglass_empty_sharp
        : isDappTx
            ? Symbols.apps_sharp
            : transaction.icon;

    return ListTile(
      leading: IconBadge(
        icon: tileIcon,
        backgroundColor: isPending
            ? semantic.warning.colorContainer
            : isDappTx
                ? colorScheme.tertiaryContainer
                : colorScheme.secondaryContainer,
        iconColor: isPending
            ? semantic.warning.onColorContainer
            : isDappTx
                ? colorScheme.onTertiaryContainer
                : colorScheme.onSecondaryContainer,
      ),
      title: Text(titleText),
      subtitle: Text(
        _displayDetails(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${transaction.formattedAmount} ${transaction.tokenSymbol}',
          ),
          Text(
            transaction.timeAgo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
