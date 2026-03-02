import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';
import 'package:crypto_mobile_app/core/widgets/produced_block_card.dart';
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

import 'node_peers_screen.dart';

final _log = LoggingService.instance.withTag('usernode/NodeStatusScreen');

class NodeStatusScreen extends ConsumerStatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  ConsumerState<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends ConsumerState<NodeStatusScreen>
    with SingleTickerProviderStateMixin {
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
  late final TabController _tabController;

  // ============== LIFECYCLE ==============

  @override
  void initState() {
    super.initState();
    _log.debug('NodeStatusScreen initialized');
    _tabController = TabController(length: 2, vsync: this);

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
    _tabController.dispose();
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.all(spacing.space16),
            children: [
              if (_error != null) _buildErrorSection(theme, colorScheme, l10n),
              _buildCentralStatusIndicator(context),
              SizedBox(height: spacing.space48),
              _buildBlockSyncProgressSection(context),
              SizedBox(height: spacing.space4),
              _buildSyncDetailsSection(context),
              SizedBox(height: spacing.space8),
              _buildRecentBlocksSection(context),
              SizedBox(height: spacing.space8),
              SizedBox(height: spacing.space32),
            ],
          ),
        ),
      ),
    );
  }

  // ============== UI SECTIONS ==============

  Widget _buildErrorSection(
      ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.commonError, style: TextStyle(color: colorScheme.error)),
        SizedBox(height: spacing.space8),
        Text(_error!, style: theme.textTheme.bodySmall),
        SizedBox(height: spacing.space16),
      ],
    );
  }

  Widget _buildCentralStatusIndicator(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final sync = statusFromProvider?.syncStatus;

    // Determine status display
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final (statusIcon, statusLabel, circleColor) =
        _getStatusDisplay(sync, semantic, colorScheme);

    return Column(
      children: [
        SizedBox(height: spacing.space16),
        // Large circular indicator
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: circleColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon,
              size: 40, color: circleColor.withValues(alpha: 0.8)),
        ),
        SizedBox(height: spacing.space16),
        // Status text
        Text(
          statusLabel,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
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
              SizedBox(width: spacing.space8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _chainId ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chain ID copied to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Icon(
                  Symbols.content_copy_sharp,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
        ...[
          Align(
            alignment: Alignment.center,
            child: Text(
              _formatLastChecked(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }

  (IconData, String, Color) _getStatusDisplay(
    dynamic sync,
    AppSemanticColors semantic,
    ColorScheme colorScheme,
  ) {
    if (_error != null) {
      return (Symbols.close_sharp, 'Offline', colorScheme.error);
    }
    if (sync == null || sync.isConnecting) {
      return (
        Symbols.hourglass_empty_sharp,
        'Connecting',
        semantic.warning.color,
      );
    }
    if (sync.isSynced) {
      return (Symbols.check_sharp, 'Synced', semantic.success.color);
    }
    return (
      Symbols.hourglass_empty_sharp,
      'Syncing',
      semantic.warning.color,
    );
  }

  Widget _buildBlockSyncProgressSection(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final theme = Theme.of(context);
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: radii.borderRadiusTopLargeIncreased,
      ),
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
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '$progressPercent%',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: spacing.space12),
          AppProgressBar(
            value: mainProgress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: colorScheme.primary,
            height: 8,
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: radii.borderRadiusBottomLargeIncreased,
      ),
      padding: EdgeInsets.all(spacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.space12,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.space12),
            child: Text(
              'Sync Details',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          _buildSyncDetailsCard(
            context: context,
            icon: Symbols.hub_sharp,
            iconColor: colorScheme.secondary,
            title: const Text('Peers'),
            subtitle: _buildPeersSubtitle(context),
            trailing: _buildPeersTrailing(),
            onTap: _navigateToPeers,
          ),
          _buildSyncDetailsCard(
            context: context,
            icon: Symbols.collections_bookmark_sharp,
            iconColor: colorScheme.secondary,
            title: _buildEpochTitle(),
            subtitle: _buildEpochSubtitle(),
            trailing: _buildEpochTrailing(),
            onTap: () {
              final epoch =
                  ref.read(nodeStatusProvider).value?.currentEpoch ?? 0;
              context.push(
                AppRoutes.epochPerformance,
                extra: {'initialEpoch': epoch},
              );
            },
          ),
          _buildSyncDetailsCard(
            context: context,
            icon: Symbols.calculate_sharp,
            iconColor: colorScheme.tertiary,
            title: const Text('VRF'),
            subtitle: _buildVrfSubtitle(),
            trailing: _buildVrfTrailing(),
          ),
          _buildSyncDetailsCard(
            context: context,
            icon: Symbols.star_sharp,
            iconColor: colorScheme.primary,
            title: const Text('Best Tip'),
            subtitle: _buildBestTipSubtitle(),
            trailing: Icon(Symbols.content_copy_sharp,
                color: colorScheme.primary, size: 20),
          ),
          _buildSyncDetailsCard(
            context: context,
            icon: Symbols.account_tree_sharp,
            iconColor: colorScheme.secondary,
            title: const Text('Mempool'),
            subtitle: _buildMempoolSubtitle(),
            trailing: _buildMempoolTrailing(),
            onTap: () => context.push(AppRoutes.mainNodeMempool),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncDetailsCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Widget title,
    required Widget subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardContent = Container(
      padding: EdgeInsets.symmetric(
          vertical: spacing.space8, horizontal: spacing.space8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: radii.borderRadiusMedium,
            ),
            child: Icon(icon, color: colorScheme.onSurface, size: 24),
          ),
          SizedBox(width: spacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ) ??
                      const TextStyle(),
                  child: title,
                ),
                SizedBox(height: spacing.space4),
                DefaultTextStyle(
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w400,
                      ) ??
                      const TextStyle(),
                  child: subtitle,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: spacing.space8),
            trailing,
          ],
          if (onTap != null) ...[
            SizedBox(width: spacing.space8),
            Icon(Symbols.chevron_right_sharp,
                color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ],
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: radii.borderRadiusMedium,
            child: cardContent)
        : cardContent;
  }

  Widget _buildDiaryCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.symmetric(
          horizontal: spacing.space16, vertical: spacing.space12),
      color: colorScheme.surfaceBright,
      borderRadius: radii.borderRadiusLargeIncreased,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRecentBlocksSection(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
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
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
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
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: spacing.space4),
                      Icon(Symbols.arrow_forward_sharp,
                          size: 14, color: colorScheme.primary),
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
    // Get reward per block from epoch rewards, with fallback to reasonable default
    final rewardsAsync = ref.read(epochRewardsProvider);
    final rewardPerBlock = rewardsAsync.value?.rewardPerBlock ?? BigInt.zero;

    return Column(
      children: [
        for (final block in blocks)
          ProducedBlockCard(
            block: block,
            isBestTip: bestTipSlot != null && block.globalSlot == bestTipSlot,
            customHash: _safeGetBlockHash(block),
            customProducer: _safeGetBlockProducer(block),
            rewardPerBlock: rewardPerBlock,
            variant: BlockCardVariant.detailed,
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

  Widget _buildPeersSubtitle(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final connectedPeers = statusFromProvider?.connectedPeers ?? 0;
    final totalPeers = statusFromProvider?.totalPeers ?? 0;

    final healthStatus = connectedPeers > 0 && connectedPeers == totalPeers
        ? 'All connected'
        : 'Some offline';

    final peerId = statusFromProvider?.peerId;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (peerId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$connectedPeers/$totalPeers $healthStatus'),
          SizedBox(height: spacing.space4),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: peerId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Peer ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Icon(
                  Symbols.content_copy_sharp,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(width: spacing.space8),
              const Text('Peer ID: '),
              Expanded(
                child: Text(
                  Utils.shortenID(peerId, head: 8, tail: 8),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Text('$connectedPeers/$totalPeers $healthStatus');
  }

  Widget _buildPeersTrailing() {
    final connectedPeers =
        ref.read(nodeStatusProvider).value?.connectedPeers ?? 0;
    return Text(
      '$connectedPeers',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildEpochTitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final currentEpoch = statusFromProvider?.currentEpoch ?? 0;
    return Text('Epoch $currentEpoch');
  }

  Widget _buildEpochSubtitle() {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final currentSlot = statusFromProvider?.currentGlobalSlot ?? 0;
    final slotsPerEpoch = statusFromProvider?.slotsInEpoch ?? 0;
    final slotInEpoch = slotsPerEpoch > 0 ? currentSlot % slotsPerEpoch : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Epoch Slot:$slotInEpoch/$slotsPerEpoch'),
        SizedBox(height: spacing.space4),
        Text('Global slot:$currentSlot'),
      ],
    );
  }

  Widget _buildEpochTrailing() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final currentSlot = statusFromProvider?.currentGlobalSlot ?? 0;
    final slotsPerEpoch = statusFromProvider?.slotsInEpoch ?? 0;
    final slotInEpoch = slotsPerEpoch > 0 ? currentSlot % slotsPerEpoch : 0;
    final progress =
        slotsPerEpoch > 0 ? (slotInEpoch / slotsPerEpoch * 100) : 0.0;

    return Text(
      '${progress.round()}%',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildVrfSubtitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final vrf = statusFromProvider?.vrfEvaluator;
    if (vrf == null) return const Text('Evaluated ---');

    final evaluatedSlots = vrf.details?.evaluatedCurrentEpoch ?? 0;
    final slotsPerEpoch = statusFromProvider?.slotsInEpoch ?? 0;
    return Text('Evaluated $evaluatedSlots/$slotsPerEpoch');
  }

  Widget _buildVrfTrailing() {
    final vrf = ref.read(nodeStatusProvider).value?.vrfEvaluator;
    final theme = Theme.of(context);

    if (vrf == null) {
      return Text(
        'N/A',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final statusText = _mapVrfStatus(vrf.currentEpochVrfEvaluationStatus.name);
    return Text(
      statusText,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _mapVrfStatus(String statusName) {
    switch (statusName.toLowerCase()) {
      case 'ready':
        return 'Ready';
      case 'pending':
        return 'Pending';
      case 'evaluating':
        return 'Evaluating';
      default:
        return statusName.isNotEmpty
            ? '${statusName[0].toUpperCase()}${statusName.substring(1)}'
            : 'Pending';
    }
  }

  Widget _buildBestTipSubtitle() {
    final status = ref.read(nodeStatusProvider).value;
    final displayBestTip = status?.networkBest ?? status?.localBest;

    if (displayBestTip == null) {
      return const Text('N/A');
    }

    final hash = displayBestTip.hash.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Utils.shortenID(hash, head: 10, tail: 10),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMempoolSubtitle() {
    final mempool = ref.read(nodeMempoolProvider).value;
    if (mempool == null) return const Text('N/A');

    final count = mempool.count.toInt();
    final sizeKB = (mempool.totalSize.toInt() / 1024).toStringAsFixed(1);
    final orphans = mempool.orphans.toInt();
    return Text('$count txns, $sizeKB KB, $orphans orphans');
  }

  Widget _buildMempoolTrailing() {
    final count = ref.read(nodeMempoolProvider).value?.count.toInt() ?? 0;
    return Text(
      '$count',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  // ============== NAVIGATION ==============

  void _navigateToPeers() {
    final status = ref.read(nodeStatusProvider).value;
    final peers = status?.peers.isNotEmpty == true ? status!.peers : _peers;
    if (peers.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NodePeersScreen(peers: peers)),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(spacing.space12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: radii.borderRadiusSmall,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: spacing.space8),
          Text(
            'Done: $done',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Pending: $pending',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Idle: $idle',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============== UTILITY METHODS ==============

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

  String _safeGetBlockHash(dynamic block) {
    try {
      return block.hash.toString();
    } catch (_) {
      return 'N/A';
    }
  }

  String _safeGetBlockProducer(dynamic block) {
    try {
      return block.producerPubkey;
    } catch (_) {
      return '';
    }
  }
}
