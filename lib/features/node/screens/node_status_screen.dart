import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';
import 'package:crypto_mobile_app/core/widgets/produced_block_card.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/features/node/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
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
  int? _currentBlockHeight;
  int? _networkBestTipHeight;
  int? _bestTipGlobalSlot;

  DateTime? _lastChecked;
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
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
    _startTimer();
  }

  @override
  void dispose() {
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
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      // Refresh all providers in parallel
      await Future.wait([
        ref.read(nodeStatusProvider.notifier).refresh(),
        ref.read(nodeMempoolProvider.notifier).refresh(),
        ref.read(nodeBlockchainProvider.notifier).refresh(),
      ]);

      await _loadChainMetadata();

      if (!mounted) return;

      final status = ref.read(nodeStatusProvider).value;
      if (status != null) {
        final localBestTip = status.localBest;
        final networkBestTip = status.networkBest;
        final displayBestTip = networkBestTip ?? localBestTip;

        setState(() {
          _peers = status.peers;
          _currentBlockHeight = localBestTip?.height;
          _networkBestTipHeight = networkBestTip?.height;
          _bestTipGlobalSlot = displayBestTip?.globalSlot;
          _lastChecked = DateTime.now();
        });
      }
    } on StateError catch (e, st) {
      _log.debug('Skipped refresh on disposed node screen');
      _log.debug('StateError during refresh: $e\n$st');
    } catch (e, st) {
      _log.error('Refresh failed', error: e, stackTrace: st);
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // ============== TIMER MANAGEMENT ==============

  void _startTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _active && !_refreshing) _refresh();
    });
  }

  void _stopTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  // ============== BUILD ==============

  @override
  Widget build(BuildContext context) {
    // React to tab changes
    final currentTab = ref.watch(currentHomeTabProvider);
    final shouldBeActive = currentTab == 1;
    if (shouldBeActive != _active) {
      _active = shouldBeActive;
      shouldBeActive ? _startTimer() : _stopTimer();
    }

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
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) _buildErrorSection(theme, colorScheme, l10n),
              _buildCentralStatusIndicator(context),
              const SizedBox(height: 32),
              _buildEpochProgressSection(context),
              const SizedBox(height: 2),
              _buildSyncDetailsSection(context),
              const SizedBox(height: 8),
              _buildRecentBlocksSection(context),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ============== UI SECTIONS ==============

  Widget _buildErrorSection(
      ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.commonError, style: TextStyle(color: colorScheme.error)),
        const SizedBox(height: 6),
        Text(_error!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCentralStatusIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final sync = statusFromProvider?.syncStatus;
    final syncPercentage = sync?.progress ?? 0.0;

    // Determine block display text
    final blockDisplayText = _getBlockDisplayText(statusFromProvider, sync);

    // Determine status display
    final (statusIcon, statusLabel, circleColor) = _getStatusDisplay(sync);

    return Column(
      children: [
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        // Status text
        Text(
          statusLabel,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        // Block sync details
        if (blockDisplayText.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                blockDisplayText,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${(syncPercentage * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: circleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        if (_lastChecked != null) ...[
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
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _getBlockDisplayText(dynamic statusFromProvider, dynamic sync) {
    if (sync == null || sync.isConnecting) return '';

    final currentHeight =
        statusFromProvider?.localBestHeight ?? _currentBlockHeight ?? 0;
    final networkHeight = statusFromProvider?.networkBestHeight ??
        _networkBestTipHeight ??
        currentHeight;

    if (sync.isSynced) {
      return 'Block $currentHeight / $networkHeight';
    }

    if (sync.appliedBlocks != null && sync.targetBlocks != null) {
      return 'Block ${Utils.formatBigInt(sync.appliedBlocks!)} / ${Utils.formatBigInt(sync.targetBlocks!)}';
    }

    return 'Block $currentHeight / $networkHeight';
  }

  (IconData, String, Color) _getStatusDisplay(dynamic sync) {
    if (_error != null) {
      return (Icons.close, 'Offline', const Color(0xFFF56E98));
    }
    if (sync == null || sync.isConnecting) {
      return (Icons.hourglass_empty, 'Connecting', const Color(0xFFF1B440));
    }
    if (sync.isSynced) {
      return (Icons.check, 'Synced', const Color(0xFF4CAF50));
    }
    return (Icons.hourglass_empty, 'Syncing', const Color(0xFFF1B440));
  }

  Widget _buildEpochProgressSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusFromProvider = ref.read(nodeStatusProvider).value;

    final currentEpoch = statusFromProvider?.currentEpoch ?? 0;
    final currentGlobalSlot = statusFromProvider?.currentGlobalSlot ?? 0;
    final slotsInEpoch = statusFromProvider?.slotsInEpoch ?? 1;

    final epochSlotPosition = currentGlobalSlot % slotsInEpoch;
    final epochProgress = (epochSlotPosition / slotsInEpoch * 100).round();

    final slotsRemaining = slotsInEpoch - epochSlotPosition;
    final secondsRemaining = slotsRemaining * 3;
    final hoursRemaining = secondsRemaining ~/ 3600;
    final minutesRemaining = (secondsRemaining % 3600) ~/ 60;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Epoch $currentEpoch',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '$epochProgress%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(
            value: epochProgress / 100.0,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: colorScheme.primary,
            height: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current slot: $epochSlotPosition / $slotsInEpoch',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              Text(
                '${hoursRemaining}h ${minutesRemaining}m left',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncDetailsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
            child: Text(
              'Sync Details',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 10),
          _buildSyncDetailsCard(
            context: context,
            icon: Icons.layers_outlined,
            iconColor: colorScheme.secondary,
            title: 'Chain',
            subtitle: _buildChainSubtitle(),
            trailing: Icon(Icons.copy, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(height: 12),
          _buildSyncDetailsCard(
            context: context,
            icon: Icons.sync,
            iconColor: colorScheme.primary,
            title: 'Node Sync Status',
            subtitle: _buildNodeSyncStatusSubtitle(),
          ),
          const SizedBox(height: 12),
          _buildSyncDetailsCard(
            context: context,
            icon: Icons.hub_outlined,
            iconColor: colorScheme.secondary,
            title: 'Peers',
            subtitle: _buildPeersSubtitle(),
            trailing: _buildPeersTrailing(),
            onTap: _navigateToPeers,
          ),
          const SizedBox(height: 12),
          _buildSyncDetailsCard(
            context: context,
            icon: Icons.calculate_outlined,
            iconColor: colorScheme.tertiary,
            title: 'VRF',
            subtitle: _buildVrfSubtitle(),
            trailing: _buildVrfTrailing(),
          ),
          const SizedBox(height: 12),
          _buildSyncDetailsCard(
            context: context,
            icon: Icons.star_border_outlined,
            iconColor: colorScheme.primary,
            title: 'Best Tip',
            subtitle: _buildBestTipSubtitle(),
            trailing: Icon(Icons.copy, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(height: 12),
          _buildSyncDetailsCard(
            context: context,
            icon: Icons.account_tree,
            iconColor: colorScheme.secondary,
            title: 'Mempool',
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
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.onSurface, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ],
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: cardContent)
        : cardContent;
  }

  Widget _buildDiaryCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRecentBlocksSection(BuildContext context) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward,
                          size: 14, color: colorScheme.primary),
                    ],
                  ),
                ),
              Icon(
                _isRecentBlocksExpanded ? Icons.expand_less : Icons.expand_more,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (_isRecentBlocksExpanded) ...[
          const SizedBox(height: 12),
          _buildProducedBlocksTab(context),
        ],
      ],
    );
  }

  Widget _buildProducedBlocksTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchain = ref.read(nodeBlockchainProvider).value;
    final status = ref.read(nodeStatusProvider).value;

    if (blockchain == null || blockchain.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
    final rewardPerBlock = BigInt.from(20);

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

  String _buildNodeSyncStatusSubtitle() {
    final status = ref.read(nodeStatusProvider).value;
    final fetchProgress = status?.fetchProgress;
    final applyProgress = status?.applyProgress;

    final (fetchPct, fetchCounts) = _calculateProgress(fetchProgress);
    final (applyPct, applyCounts) = _calculateProgress(applyProgress);

    return 'Fetched blocks ${fetchPct.toStringAsFixed(0)}% $fetchCounts | Applied blocks ${applyPct.toStringAsFixed(0)}% $applyCounts';
  }

  (double, String) _calculateProgress(dynamic progress) {
    if (progress == null) return (100.0, '');
    final total = progress.idle + progress.pending + progress.done;
    if (total <= BigInt.zero) return (100.0, '');
    final pct = (progress.done.toDouble() / total.toDouble()) * 100;
    return (pct, '(${progress.done}/$total)');
  }

  String _buildPeersSubtitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final connectedPeers = statusFromProvider?.connectedPeers ?? 0;
    final totalPeers = statusFromProvider?.totalPeers ?? 0;

    final healthStatus = connectedPeers > 0 && connectedPeers == totalPeers
        ? 'All connected'
        : 'Some offline';

    final peerId = statusFromProvider?.peerId;
    final peerIdText = peerId != null
        ? '\nPeer ID: ${Utils.shortenID(peerId, head: 8, tail: 8)}'
        : '';

    return '$connectedPeers/$totalPeers $healthStatus$peerIdText';
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

  String _buildVrfSubtitle() {
    final statusFromProvider = ref.read(nodeStatusProvider).value;
    final vrf = statusFromProvider?.vrfEvaluator;
    if (vrf == null) return 'Evaluated ---';

    final evaluatedSlots = vrf.details?.evaluatedCurrentEpoch ?? 0;
    final slotsPerEpoch = statusFromProvider?.slotsInEpoch ?? 720;
    return 'Evaluated $evaluatedSlots/$slotsPerEpoch';
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

  String _buildBestTipSubtitle() {
    final status = ref.read(nodeStatusProvider).value;
    final displayBestTip = status?.networkBest ?? status?.localBest;
    if (displayBestTip == null) return 'N/A';

    final height = displayBestTip.height;
    final slot = status?.globalSlot ?? _bestTipGlobalSlot;
    final hash = displayBestTip.hash.toString();
    final truncatedHash = Utils.shortenID(hash, head: 8, tail: 8);

    return 'Height $height, Slot ${slot ?? 'N/A'}, $truncatedHash';
  }

  String _buildChainSubtitle() {
    final chainIdText =
        Utils.shortenID(_chainId ?? 'Loading...', head: 8, tail: 8);
    final chainNameText = _chainName ?? 'Loading...';
    return 'ID: $chainIdText\nName: $chainNameText';
  }

  String _buildMempoolSubtitle() {
    final mempool = ref.read(nodeMempoolProvider).value;
    if (mempool == null) return 'N/A';

    final count = mempool.count.toInt();
    final sizeKB = (mempool.totalSize.toInt() / 1024).toStringAsFixed(1);
    final orphans = mempool.orphans.toInt();
    return '$count txns, $sizeKB KB, $orphans orphans';
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

  // ============== UTILITY METHODS ==============
  String _formatLastChecked() {
    if (_lastChecked == null) return '';

    final now = DateTime.now();
    final checked = _lastChecked!;
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
