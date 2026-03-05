import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_data_providers.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _log = LoggingService.instance.withTag('usernode/NodeStatusScreen');

class NodeStatusScreen extends ConsumerStatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  ConsumerState<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends ConsumerState<NodeStatusScreen> {
  final _scrollFraction = ValueNotifier<double>(0.0);

  // State flags
  bool _refreshing = false;
  String? _error;
  bool _active = true;
  bool _isRecentBlocksExpanded = false;

  // Cached data
  List<RpcPeerInfo> _peers = const [];
  int? _bestTipGlobalSlot;

  DateTime _lastChecked = DateTime.now();
  String? _deviceId;
  String? _chainId;
  String? _chainName;

  // Network-specific caches (consolidated into maps)
  final Map<NetworkType, String> _chainIdCache = {};
  final Map<NetworkType, String> _chainNameCache = {};

  Timer? _autoTimer;

  // ============== LIFECYCLE ==============

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _startTimer();
    });

    // React to tab changes — start/stop timer when node tab becomes active.
    ref.listenManual(currentHomeTabProvider, (previous, next) {
      final shouldBeActive = next == HomeTab.nodeStatus;
      if (shouldBeActive != _active) {
        _active = shouldBeActive;
        if (shouldBeActive) {
          _startTimer();
        } else {
          _stopTimer();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollFraction.dispose();
    _autoTimer?.cancel();
    super.dispose();
  }

  // ============== INITIALIZATION ==============

  /// Initialize all data in parallel where possible
  Future<void> _initializeData() async {
    await Future.wait([
      _refresh(),
      _loadDeviceId(),
      _loadChainMetadata(),
    ], eagerError: false);
  }

  Future<void> _loadDeviceId() async {
    if (_deviceId != null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final rawDeviceId = Platform.isAndroid
          ? (await deviceInfo.androidInfo).id
          : Platform.isIOS
              ? (await deviceInfo.iosInfo).identifierForVendor ?? 'unknown'
              : 'unknown';

      final hashedDeviceId = md5.convert(utf8.encode(rawDeviceId)).toString();
      if (!mounted) return;
      setState(() => _deviceId = hashedDeviceId);
    } catch (e) {
      _log.debug('Failed to load device ID: $e');
    }
  }

  /// Consolidated chain metadata loading (chainId + chainName)
  Future<void> _loadChainMetadata() async {
    NetworkType? currentNetwork;
    try {
      currentNetwork = await RustBackendService.instance.getSelectedNetwork();
    } catch (e) {
      _log.debug('Failed to get network type: $e');
      return;
    }

    // Check caches first
    final cachedId = _chainIdCache[currentNetwork];
    final cachedName = _chainNameCache[currentNetwork];

    if (cachedId != null && cachedName != null) {
      if (!mounted) return;
      setState(() {
        _chainId = cachedId;
        _chainName = cachedName;
      });
      return;
    }

    if (!mounted) return;

    // Fetch from status (single call for both values)
    try {
      final status = await RustBackendService.instance.getStatus();
      final chainId = status?.node.chainId.toString();
      final chainName = status?.node.chainName;

      // Cache valid results
      if (chainId != null && chainId.isNotEmpty) {
        _chainIdCache[currentNetwork] = chainId;
      }
      if (chainName != null && chainName.isNotEmpty) {
        _chainNameCache[currentNetwork] = chainName;
      }

      if (!mounted) return;
      setState(() {
        _chainId = chainId?.isNotEmpty == true ? chainId : null;
        _chainName = chainName?.isNotEmpty == true ? chainName : null;
      });
    } catch (e) {
      _log.debug('Failed to get chain metadata: $e');
    }
  }

  // ============== REFRESH LOGIC ==============

  Future<void> _refresh() async {
    if (!mounted) return;

    _error = null;
    setState(() {
      _refreshing = true;
    });

    try {
      await Future.wait([
        ref.read(nodeStatusProvider.notifier).refresh(),
        ref.read(nodeMempoolProvider.notifier).refresh(),
        ref.read(nodeBlockchainProvider.notifier).refresh(),
      ]);

      await _loadChainMetadata();

      if (!mounted) return;

      final status = ref.read(nodeStatusProvider).value;
      if (status != null) {
        final displayBestTip = status.networkBest ?? status.localBest;
        _peers = status.peers;
        _bestTipGlobalSlot = displayBestTip?.globalSlot;
      }
    } on StateError {
      // Provider disposed during refresh — ignore.
    } catch (e, st) {
      _log.error('Refresh failed', error: e, stackTrace: st);
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _lastChecked = DateTime.now();
        });
      }
    }
  }

  // ============== TIMER MANAGEMENT ==============

  void _startTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _active && !_refreshing) {
        _refresh();
      }
    });
  }

  void _stopTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  // ============== BUILD ==============

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final hasRecentBlocks =
        ref.read(nodeBlockchainProvider).value?.items.isNotEmpty ?? false;

    return Scaffold(
      drawer: const AppDrawer(),
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight,
        scrollFractionNotifier: _scrollFraction,
        onRefresh: _refresh,
        header: _buildCentralStatusIndicator(context),
        surfaceSlivers: [
          if (_error != null)
            SliverToBoxAdapter(
                child: _buildErrorSection(theme, colorScheme, l10n)),
          SliverToBoxAdapter(child: _buildBlockSyncProgressSection(context)),
          SliverToBoxAdapter(child: _buildSyncDetailsSection(context)),
          if (hasRecentBlocks)
            SliverToBoxAdapter(child: SizedBox(height: spacing.space8)),
          SliverToBoxAdapter(child: _buildRecentBlocksSection(context)),
          SliverToBoxAdapter(child: SizedBox(height: spacing.space32)),
        ],
      ),
    );
  }

  // ============== UI SECTIONS ==============

  Widget _buildErrorSection(
      ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space16),
      child: MaterialBanner(
        backgroundColor: colorScheme.errorContainer,
        leading: Icon(Symbols.error_sharp, color: colorScheme.onErrorContainer),
        content: Text(
          _error!,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onErrorContainer),
        ),
        actions: [
          TextButton(
            onPressed: _refresh,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralStatusIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final colorScheme = theme.colorScheme;
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final sync = statusFromProvider?.syncStatus;

    // Determine status display
    final semantic = theme.extension<AppSemanticColors>()!;
    final (statusIcon, statusLabel, circleBg, circleIcon) =
        _getStatusDisplay(sync, semantic, colorScheme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large circular indicator
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, size: sizing.iconDisplay, color: circleIcon),
        ),
        SizedBox(height: spacing.space16),
        // Status text
        Text(
          statusLabel,
          style: theme.textTheme.displaySmall
              ?.copyWith(fontFamily: kMonoFontFamily),
        ),
        SizedBox(height: spacing.space8),
        // Chain name with copy functionality
        if (_chainName != null && _chainName!.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _chainName!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              _buildCopyButton(
                text: _chainId ?? '',
                message: AppLocalizations.of(context).nodeChainIdCopied,
                iconSize: sizing.iconXSmall,
              ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.center,
          child: Text(
            _formatLastChecked(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// Returns (icon, label, backgroundFill, iconColor) using semantic roles.
  (IconData, String, Color, Color) _getStatusDisplay(
    dynamic sync,
    AppSemanticColors semantic,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return (
        Symbols.close_sharp,
        l10n.nodeOffline,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      );
    }
    if (sync == null || sync.isConnecting) {
      return (
        Symbols.hourglass_empty_sharp,
        l10n.nodeConnecting,
        semantic.warning.colorContainer,
        semantic.warning.onColorContainer,
      );
    }
    if (sync.isSynced) {
      return (
        Symbols.check_sharp,
        l10n.nodeSynced,
        semantic.success.colorContainer,
        semantic.success.onColorContainer,
      );
    }
    return (
      Symbols.hourglass_empty_sharp,
      l10n.nodeSyncing,
      semantic.warning.colorContainer,
      semantic.warning.onColorContainer,
    );
  }

  Widget _buildBlockSyncProgressSection(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final colorScheme = theme.colorScheme;
    final statusFromProvider = ref.read(nodeStatusProvider).value;

    final sync = statusFromProvider?.syncStatus;
    final isNodeSynced = sync?.isSynced == true;

    // Get fetch and apply progress percentages and counts
    final fetchProgress = statusFromProvider?.fetchProgress;
    final applyProgress = statusFromProvider?.applyProgress;
    final (fetchPct, fetchCounts) = _calculateProgress(fetchProgress);
    final (applyPct, applyCounts) = _calculateProgress(applyProgress);

    // Use only applied blocks progress for main progress bar
    final mainProgress = sync?.progress ?? 0.0;
    final progressPercent = (mainProgress * 100).round();

    // Use different display values based on sync status
    final l10n = AppLocalizations.of(context);
    final (
      displayCurrentBlocks,
      displayTotalBlocks,
      displayText
    ) = sync?.isConnecting == true || sync == null
        ? (
            // When connecting or sync status unavailable: show connecting message
            BigInt.zero,
            BigInt.zero,
            l10n.nodeConnectingEllipsis,
          )
        : isNodeSynced
            ? (
                // When synced: check if genesis block (height 1) for special display
                (statusFromProvider?.localBestHeight ?? 0) == 1
                    ? (BigInt.zero, BigInt.zero, l10n.nodeLoadedGenesis)
                    : (
                        BigInt.from(statusFromProvider?.localBestHeight ?? 0),
                        BigInt.from(statusFromProvider?.localBestHeight ?? 0),
                        l10n.nodeChainSynced,
                      ))
            : (
                // When syncing: use apply progress
                applyProgress?.done ?? BigInt.zero,
                ((applyProgress?.idle ?? BigInt.zero) +
                    (applyProgress?.pending ?? BigInt.zero) +
                    (applyProgress?.done ?? BigInt.zero)),
                l10n.nodeSyncingBlocks,
              );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.space24,
        spacing.space24,
        spacing.space24,
        spacing.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sync?.isConnecting == true || sync == null
                    ? displayText
                    : displayText == l10n.nodeLoadedGenesis
                        ? displayText
                        : '$displayText $displayCurrentBlocks/$displayTotalBlocks',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '$progressPercent%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.space12),
          AppProgressBar(
            value: mainProgress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: colorScheme.primary,
            height: spacing.space8,
          ),
          if (sync?.isSyncing == true) ...[
            SizedBox(height: spacing.space12),
            Row(
              children: [
                Expanded(
                  child: _buildPhaseCard(
                    context: context,
                    title: l10n.nodeFetchPhase,
                    progress: fetchPct,
                    done: fetchProgress?.done ?? BigInt.zero,
                    pending: fetchProgress?.pending ?? BigInt.zero,
                    idle: fetchProgress?.idle ?? BigInt.zero,
                  ),
                ),
                SizedBox(width: spacing.space8),
                Expanded(
                  child: _buildPhaseCard(
                    context: context,
                    title: l10n.nodeApplyPhase,
                    progress: applyPct,
                    done: applyProgress?.done ?? BigInt.zero,
                    pending: applyProgress?.pending ?? BigInt.zero,
                    idle: applyProgress?.idle ?? BigInt.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncDetailsSection(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final status = ref.read(nodeStatusProvider).value;
    final vrf = status?.vrfEvaluator;
    final displayBestTip = status?.networkBest ?? status?.localBest;
    final bestTipHash = displayBestTip?.hash.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Navigable rows ---
        ListTile(
          leading: const IconBadge(icon: Symbols.hub_sharp),
          title: Text(l10n.nodePeers),
          subtitle: _buildPeersSubtitle(),
          trailing: TextChevronTrailing(
            text: '${status?.connectedPeers ?? 0}',
          ),
          onTap: _navigateToPeers,
        ),
        ListTile(
          leading: const IconBadge(icon: Symbols.collections_bookmark_sharp),
          title: _buildEpochTitle(),
          subtitle: _buildEpochSubtitle(),
          trailing: TextChevronTrailing(
            text: _buildEpochTrailingText(),
          ),
          onTap: () {
            final epoch = ref.read(nodeStatusProvider).value?.currentEpoch ?? 0;
            context.push(
              AppRoutes.epochPerformance,
              extra: {'initialEpoch': epoch},
            );
          },
        ),
        ListTile(
          leading: const IconBadge(icon: Symbols.account_tree_sharp),
          title: Text(l10n.nodeMempool),
          subtitle: _buildMempoolSubtitle(),
          trailing: TextChevronTrailing(
            text: '${ref.read(nodeMempoolProvider).value?.count.toInt() ?? 0}',
          ),
          onTap: () => context.push(AppRoutes.mainNodeMempool),
        ),

        SizedBox(height: spacing.space4),

        // --- Reference/status data ---
        Card(
          elevation: 0,
          margin: EdgeInsets.symmetric(horizontal: spacing.space24),
          shape: RoundedRectangleBorder(
            borderRadius: radii.borderRadiusLarge,
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InfoRow(
                label: l10n.nodeVrf,
                value: vrf != null
                    ? l10n.nodeVrfEvaluated(
                        vrf.details?.evaluatedCurrentEpoch ?? 0,
                        status?.slotsInEpoch ?? 0)
                    : l10n.nodeVrfEvaluatedNA,
                trailing: StatusBadge(
                  label: vrf != null
                      ? _mapVrfEvaluationLabel(
                          vrf.currentEpochVrfEvaluationStatus)
                      : l10n.nodeNotAvailable,
                  variant: _vrfEvaluationVariant(
                      vrf?.currentEpochVrfEvaluationStatus),
                ),
              ),
              InfoRow(
                label: l10n.nodeBestTip,
                value: bestTipHash.isNotEmpty
                    ? Utils.shortenID(bestTipHash, head: 8, tail: 6)
                    : l10n.nodeNotAvailable,
                valueStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: kMonoFontFamily,
                ),
                trailing: _buildCopyButton(
                  text: bestTipHash,
                  message: l10n.nodeBestTipCopied,
                  iconSize: sizing.iconSmall,
                ),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiaryCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final colorScheme = theme.colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: spacing.space24),
      padding: EdgeInsets.symmetric(
          horizontal: spacing.space16, vertical: spacing.space12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: radii.borderRadiusLargeIncreased,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRecentBlocksSection(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final colorScheme = theme.colorScheme;

    return _buildDiaryCard(
      context: context,
      children: [
        InkWell(
          onTap: () => setState(
              () => _isRecentBlocksExpanded = !_isRecentBlocksExpanded),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).nodeRecentBlocks,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (!_isRecentBlocksExpanded)
                TextButton(
                  onPressed: () =>
                      context.push(AppRoutes.nodeStatusProducedBlocks),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacing.space8, vertical: spacing.space4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context).nodeViewAll,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: spacing.space4),
                      Icon(Symbols.arrow_forward_sharp,
                          size: sizing.iconXSmall, color: colorScheme.primary),
                    ],
                  ),
                ),
              Icon(
                _isRecentBlocksExpanded
                    ? Symbols.expand_less_sharp
                    : Symbols.expand_more_sharp,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (_isRecentBlocksExpanded) ...[
          SizedBox(height: spacing.space12),
          _buildProducedBlocksTab(context),
        ],
      ],
    );
  }

  Widget _buildProducedBlocksTab(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchain = ref.read(nodeBlockchainProvider).value;
    final status = ref.read(nodeStatusProvider).value;

    if (blockchain == null || blockchain.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final blocks = blockchain.items.take(10).toList();
    final bestTipSlot = status?.globalSlot ?? _bestTipGlobalSlot;
    final rewardsAsync = ref.read(epochRewardsProvider);
    final rewardPerBlock = rewardsAsync.value?.rewardPerBlock ?? BigInt.zero;
    final rewardText = '+${Utils.formatBigInt(rewardPerBlock)} TKN';

    return Column(
      children: [
        for (final block in blocks)
          ListTile(
            title: Row(
              children: [
                Text('Block #${block.height}'),
                if (bestTipSlot != null && block.globalSlot == bestTipSlot) ...[
                  SizedBox(width: spacing.space8),
                  StatusBadge(
                    label: AppLocalizations.of(context).nodeBestTipBadge,
                    variant: StatusBadgeVariant.info,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${Utils.timestampToTimeAgo(block.timestamp)} · '
              'Epoch ${block.epoch} · Slot ${block.globalSlot}',
            ),
            trailing: Text(
              rewardText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.tertiary,
              ),
            ),
            onTap: () => context.push(
              AppRoutes.mainNodeBlockDetails,
              extra: block,
            ),
          ),
      ],
    );
  }

  // ============== SUBTITLE BUILDERS ==============

  (double, String) _calculateProgress(dynamic progress) {
    if (progress == null) return (100.0, '');
    final total = progress.idle + progress.pending + progress.done;
    if (total <= BigInt.zero) return (100.0, '');
    final pct = (progress.done.toDouble() / total.toDouble()) * 100;
    return (pct, '(${progress.done}/$total)');
  }

  Widget _buildPeersSubtitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final connectedPeers = statusFromProvider?.connectedPeers ?? 0;
    final totalPeers = statusFromProvider?.totalPeers ?? 0;
    final l10n = AppLocalizations.of(context);
    return Text(l10n.nodePeersConnected(connectedPeers, totalPeers));
  }

  Widget _buildEpochTitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final currentEpoch = statusFromProvider?.currentEpoch ?? 0;
    final l10n = AppLocalizations.of(context);
    return Text(l10n.nodeEpochN(currentEpoch));
  }

  (int slotInEpoch, int slotsPerEpoch, int currentSlot) _epochSlotData() {
    final status = ref.read(nodeStatusProvider).value;
    final currentSlot = status?.currentGlobalSlot ?? 0;
    final slotsPerEpoch = status?.slotsInEpoch ?? 0;
    final slotInEpoch = slotsPerEpoch > 0 ? currentSlot % slotsPerEpoch : 0;
    return (slotInEpoch, slotsPerEpoch, currentSlot);
  }

  Widget _buildEpochSubtitle() {
    final (_, _, currentSlot) = _epochSlotData();
    final l10n = AppLocalizations.of(context);
    return Text(l10n.nodeGlobalSlot(currentSlot));
  }

  String _buildEpochTrailingText() {
    final (slotInEpoch, slotsPerEpoch, _) = _epochSlotData();
    final progress =
        slotsPerEpoch > 0 ? (slotInEpoch / slotsPerEpoch * 100) : 0.0;
    return '${progress.round()}%';
  }

  StatusBadgeVariant _vrfEvaluationVariant(
      RpcStatusVrfEvaluationStatus? status) {
    return switch (status) {
      RpcStatusVrfEvaluationStatus.completed => StatusBadgeVariant.success,
      RpcStatusVrfEvaluationStatus.evaluating => StatusBadgeVariant.info,
      RpcStatusVrfEvaluationStatus.pending ||
      null =>
        StatusBadgeVariant.neutral,
    };
  }

  String _mapVrfEvaluationLabel(RpcStatusVrfEvaluationStatus status) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      RpcStatusVrfEvaluationStatus.completed => l10n.nodeVrfCompleted,
      RpcStatusVrfEvaluationStatus.evaluating => l10n.nodeVrfEvaluating,
      RpcStatusVrfEvaluationStatus.pending => l10n.nodeVrfPendingLabel,
    };
  }

  Widget _buildMempoolSubtitle() {
    final mempool = ref.read(nodeMempoolProvider).value;
    final l10n = AppLocalizations.of(context);
    if (mempool == null) return Text(l10n.nodeNotAvailable);

    final count = mempool.count.toInt();
    final sizeKB = (mempool.totalSize.toInt() / 1024).toStringAsFixed(1);
    return Text(l10n.nodeMempoolSummary(count, sizeKB));
  }

  // ============== NAVIGATION ==============

  void _navigateToPeers() {
    final status = ref.read(nodeStatusProvider).value;
    final peers = status?.peers.isNotEmpty == true ? status!.peers : _peers;
    if (peers.isEmpty) return;
    context.push(
      AppRoutes.mainNodePeers,
      extra: {'peers': peers, 'peerId': status?.peerId},
    );
  }

  Widget _buildPhaseCard({
    required BuildContext context,
    required String title,
    required double progress,
    required BigInt done,
    required BigInt pending,
    required BigInt idle,
  }) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: radii.borderRadiusSmall,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodyLarge),
            SizedBox(height: spacing.space8),
            Text(AppLocalizations.of(context).nodePhaseDone('$done'),
                style: theme.textTheme.bodySmall),
            Text(AppLocalizations.of(context).nodePhasePending('$pending'),
                style: theme.textTheme.bodySmall),
            Text(AppLocalizations.of(context).nodePhaseIdle('$idle'),
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  // ============== UTILITY METHODS ==============

  Widget _buildCopyButton({
    required String text,
    required String message,
    double? iconSize,
  }) {
    final theme = Theme.of(context);
    final sizing = theme.extension<AppSizing>()!;
    return IconButton(
      icon: const Icon(Symbols.content_copy_sharp),
      iconSize: iconSize ?? sizing.iconXSmall,
      color: theme.colorScheme.primary,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  String _formatLastChecked() {
    final now = DateTime.now();
    final checked = _lastChecked;
    final l10n = AppLocalizations.of(context);
    final timeStr =
        '${checked.hour.toString().padLeft(2, '0')}:${checked.minute.toString().padLeft(2, '0')}:${checked.second.toString().padLeft(2, '0')}';

    final isToday = now.year == checked.year &&
        now.month == checked.month &&
        now.day == checked.day;

    if (isToday) {
      return l10n.commonLastCheckedAt(timeStr);
    }
    final dateStr =
        '${checked.year}-${checked.month.toString().padLeft(2, '0')}-${checked.day.toString().padLeft(2, '0')}';
    return l10n.commonLastCheckedOnAt(dateStr, timeStr);
  }
}
