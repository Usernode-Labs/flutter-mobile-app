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
import 'package:crypto_mobile_app/features/wallet/screens/wallet_delegates.dart';
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
    _log.debug('NodeStatusScreen initialized');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _log.debug(
          'Post-frame callback triggered - initializing data and starting timer');
      _initializeData();
      // Start timer immediately after post-frame to ensure continuous refresh
      _startTimer();
    });
  }

  @override
  void dispose() {
    _log.debug('NodeStatusScreen disposing - cancelling timer');
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

    // Set loading state only if no cache
    if (!mounted) return;
    setState(() {
      _chainId ??= 'Loading...';
      _chainName ??= 'Loading...';
    });

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
        _chainId = chainId?.isNotEmpty == true ? chainId : 'Loading...';
        _chainName = chainName?.isNotEmpty == true ? chainName : 'Loading...';
      });
    } catch (e) {
      _log.debug('Failed to get chain metadata: $e');
    }
  }

  // ============== REFRESH LOGIC ==============

  Future<void> _refresh() async {
    final refreshStartTime = DateTime.now();
    _log.debug('=== REFRESH START ===');
    _log.debug('Refresh triggered at ${refreshStartTime.toIso8601String()}');

    if (!mounted) {
      _log.debug('Widget not mounted, skipping refresh');
      return;
    }

    _log.debug('Setting refreshing=true and clearing error');
    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      _log.debug(
          'Starting parallel provider refresh (nodeStatus, mempool, blockchain)');
      final providerRefreshStart = DateTime.now();

      // Refresh all providers in parallel with individual timing
      await Future.wait([
        _timedProviderRefresh('nodeStatus',
            () => ref.read(nodeStatusProvider.notifier).refresh()),
        _timedProviderRefresh(
            'mempool', () => ref.read(nodeMempoolProvider.notifier).refresh()),
        _timedProviderRefresh('blockchain',
            () => ref.read(nodeBlockchainProvider.notifier).refresh()),
      ]);

      final providerRefreshDuration =
          DateTime.now().difference(providerRefreshStart);
      _log.debug(
          'Provider refresh completed in ${providerRefreshDuration.inMilliseconds}ms');

      _log.debug('Loading chain metadata');
      final chainMetadataStart = DateTime.now();
      await _loadChainMetadata();
      final chainMetadataDuration =
          DateTime.now().difference(chainMetadataStart);
      _log.debug(
          'Chain metadata loaded in ${chainMetadataDuration.inMilliseconds}ms');

      if (!mounted) {
        _log.debug('Widget unmounted during refresh, aborting');
        return;
      }

      final status = ref.read(nodeStatusProvider).value;
      if (status != null) {
        final localBestTip = status.localBest;
        final networkBestTip = status.networkBest;
        final displayBestTip = networkBestTip ?? localBestTip;

        _log.debug(
            'Status data received - updating state with peers: ${status.peers.length}, bestTip: ${displayBestTip?.globalSlot}');
        setState(() {
          _peers = status.peers;
          _bestTipGlobalSlot = displayBestTip?.globalSlot;
          _lastChecked = DateTime.now();
        });
        _log.debug('State updated successfully');
      } else {
        _log.debug(
            'Status is null (connecting state) - updating only last checked');
        // Even if status is null (connecting state), update last checked
        if (mounted) {
          setState(() {
            _lastChecked = DateTime.now();
          });
        }
      }
    } on StateError catch (e, st) {
      _log.debug('StateError during refresh: $e');
      _log.debug('StateError stackTrace: $st');
      // Update last checked even on StateError
      if (mounted) {
        _log.debug('Updating last checked after StateError');
        setState(() {
          _lastChecked = DateTime.now();
        });
      }
    } catch (e, st) {
      _log.error('Refresh failed with error: $e', error: e, stackTrace: st);
      if (mounted) {
        _log.debug('Setting error state and updating last checked');
        setState(() {
          _error = e.toString();
          _lastChecked = DateTime.now(); // Update last checked even on error
        });
      }
    } finally {
      // Always update _lastChecked and rebuild UI, even if no data changed
      if (mounted) {
        final finalUpdateTime = DateTime.now();
        _log.debug(
            'Final update - setting refreshing=false and updating last checked to ${finalUpdateTime.toIso8601String()}');
        setState(() {
          _refreshing = false;
          _lastChecked = finalUpdateTime;
        });

        final totalDuration = finalUpdateTime.difference(refreshStartTime);
        _log.debug(
            '=== REFRESH COMPLETE === Total duration: ${totalDuration.inMilliseconds}ms');
      } else {
        _log.debug('Widget unmounted in finally block');
      }
    }
  }

  // ============== TIMER MANAGEMENT ==============

  void _startTimer() {
    _autoTimer?.cancel();
    _log.debug('Starting auto refresh timer (2s interval)');
    _autoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      _log.debug(
          'Timer tick at ${now.toIso8601String()} - checking conditions...');
      _log.debug(
          'mounted: $mounted, active: $_active, refreshing: $_refreshing');

      if (mounted && _active && !_refreshing) {
        _log.debug('All conditions met - triggering auto refresh');
        _refresh();
      } else {
        _log.debug(
            'Auto refresh skipped - mounted: $mounted, active: $_active, refreshing: $_refreshing');
      }
    });
  }

  void _stopTimer() {
    _log.debug('Stopping auto refresh timer');
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  // ============== BUILD ==============

  @override
  Widget build(BuildContext context) {
    // React to tab changes
    final currentTab = ref.watch(currentHomeTabProvider);
    final shouldBeActive = currentTab == 3;
    if (shouldBeActive != _active) {
      _log.debug(
          'Tab change detected: currentTab=$currentTab, shouldBeActive=$shouldBeActive, _active=$_active');
      _active = shouldBeActive;
      if (shouldBeActive) {
        _log.debug('Node status tab activated - starting timer');
        _startTimer();
      } else {
        _log.debug('Node status tab deactivated - stopping timer');
        _stopTimer();
      }
    }

    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final safeTop = MediaQuery.of(context).padding.top;
    final hasRecentBlocks =
        ref.read(nodeBlockchainProvider).value?.items.isNotEmpty ?? false;

    final pinnedHeight =
        safeTop + spacing.space8 + kAddressBarHeight + spacing.space8;

    return Scaffold(
      drawer: const AppDrawer(),
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight,
        pinnedHeaderHeight: pinnedHeight,
        pinnedHeaderSliver: SliverToBoxAdapter(
          child: SizedBox(height: pinnedHeight),
        ),
        onRefresh: _refresh,
        header: _buildCentralStatusIndicator(context),
        surfaceBody: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) _buildErrorSection(theme, colorScheme, l10n),
            _buildBlockSyncProgressSection(context),
            SizedBox(height: spacing.space24),
            _buildSyncDetailsSection(context),
            if (hasRecentBlocks) SizedBox(height: spacing.space8),
            _buildRecentBlocksSection(context),
            SizedBox(height: spacing.space32),
          ],
        ),
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
        if (_chainName != null &&
            _chainName!.isNotEmpty &&
            _chainName != 'Loading...') ...[
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
    if (_error != null) {
      return (
        Symbols.close_sharp,
        'Offline',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      );
    }
    if (sync == null || sync.isConnecting) {
      return (
        Symbols.hourglass_empty_sharp,
        'Connecting',
        semantic.warning.colorContainer,
        semantic.warning.onColorContainer,
      );
    }
    if (sync.isSynced) {
      return (
        Symbols.check_sharp,
        'Synced',
        semantic.success.colorContainer,
        semantic.success.onColorContainer,
      );
    }
    return (
      Symbols.hourglass_empty_sharp,
      'Syncing',
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
    final (
      displayCurrentBlocks,
      displayTotalBlocks,
      displayText
    ) = sync?.isConnecting == true || sync == null
        ? (
            // When connecting or sync status unavailable: show connecting message
            BigInt.zero,
            BigInt.zero,
            'Connecting...'
          )
        : isNodeSynced
            ? (
                // When synced: check if genesis block (height 1) for special display
                (statusFromProvider?.localBestHeight ?? 0) == 1
                    ? (BigInt.zero, BigInt.zero, 'Loaded genesis')
                    : (
                        BigInt.from(statusFromProvider?.localBestHeight ?? 0),
                        BigInt.from(statusFromProvider?.localBestHeight ?? 0),
                        'Chain Synced'
                      ))
            : (
                // When syncing: use apply progress
                applyProgress?.done ?? BigInt.zero,
                ((applyProgress?.idle ?? BigInt.zero) +
                    (applyProgress?.pending ?? BigInt.zero) +
                    (applyProgress?.done ?? BigInt.zero)),
                'Syncing blocks'
              );

    return Padding(
      padding: EdgeInsets.all(spacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sync?.isConnecting == true || sync == null
                    ? displayText
                    : displayText == 'Loaded genesis'
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
                    title: 'Fetch',
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
                    title: 'Apply',
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
          title: const Text('Peers'),
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
          title: const Text('Mempool'),
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
          margin: EdgeInsets.symmetric(horizontal: spacing.space16),
          shape: RoundedRectangleBorder(
            borderRadius: radii.borderRadiusLarge,
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InfoRow(
                label: 'VRF',
                value: vrf != null
                    ? 'Evaluated ${vrf.details?.evaluatedCurrentEpoch ?? 0}/${status?.slotsInEpoch ?? 0}'
                    : 'Evaluated ---',
                trailing: StatusBadge(
                  label: vrf != null
                      ? _mapVrfEvaluationLabel(
                          vrf.currentEpochVrfEvaluationStatus)
                      : 'N/A',
                  variant: _vrfEvaluationVariant(
                      vrf?.currentEpochVrfEvaluationStatus),
                ),
              ),
              InfoRow(
                label: 'Best Tip',
                value: bestTipHash.isNotEmpty
                    ? Utils.shortenID(bestTipHash, head: 8, tail: 6)
                    : 'N/A',
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
      margin: EdgeInsets.symmetric(horizontal: spacing.space16),
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
    final blockchain = ref.read(nodeBlockchainProvider).value;

    if (blockchain == null || blockchain.items.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  'Recent Blocks',
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
                        'View All',
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
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.space24),
          child: Text(
            'No produced blocks available',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
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
                  const StatusBadge(
                    label: 'BEST TIP',
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
    return Text('$connectedPeers/$totalPeers connected');
  }

  Widget _buildEpochTitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final currentEpoch = statusFromProvider?.currentEpoch ?? 0;
    return Text('Epoch $currentEpoch');
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
    return Text('Global slot $currentSlot');
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
    return switch (status) {
      RpcStatusVrfEvaluationStatus.completed => 'Completed',
      RpcStatusVrfEvaluationStatus.evaluating => 'Evaluating',
      RpcStatusVrfEvaluationStatus.pending => 'Pending',
    };
  }

  Widget _buildMempoolSubtitle() {
    final mempool = ref.read(nodeMempoolProvider).value;
    if (mempool == null) return const Text('N/A');

    final count = mempool.count.toInt();
    final sizeKB = (mempool.totalSize.toInt() / 1024).toStringAsFixed(1);
    return Text('$count txns \u00b7 $sizeKB KB');
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
            Text('Done: $done', style: theme.textTheme.bodySmall),
            Text('Pending: $pending', style: theme.textTheme.bodySmall),
            Text('Idle: $idle', style: theme.textTheme.bodySmall),
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

  Future<void> _timedProviderRefresh(
      String providerName, Future<void> Function() refreshFunction) async {
    final stopwatch = Stopwatch()..start();
    try {
      await refreshFunction();
      stopwatch.stop();
      _log.debug(
          '$providerName provider refreshed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      _log.debug(
          '$providerName provider failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  String _formatLastChecked() {
    final now = DateTime.now();
    final checked = _lastChecked;
    final timeStr =
        '${checked.hour.toString().padLeft(2, '0')}:${checked.minute.toString().padLeft(2, '0')}:${checked.second.toString().padLeft(2, '0')}';

    final isToday = now.year == checked.year &&
        now.month == checked.month &&
        now.day == checked.day;

    if (isToday) {
      return 'Last checked at $timeStr';
    }
    return 'Last checked on ${checked.year}-${checked.month.toString().padLeft(2, '0')}-${checked.day.toString().padLeft(2, '0')} at $timeStr';
  }
}
