import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'node_peers_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/mempool_cache_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/best_tip_cache_provider.dart';
import 'package:crypto_mobile_app/core/theme/theme.dart';
import 'package:go_router/go_router.dart';

class NodeStatusScreen extends ConsumerStatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  ConsumerState<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends ConsumerState<NodeStatusScreen>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  String? _error;
  // int? _peerCount; // unused
  List<RpcPeerInfo> _peers = const [];
  int? _currentBlockHeight;
  int? _networkBestTipHeight;
  int? _bestTipGlobalSlot;
  int? _bestTipEpoch;
  String? _bestTipHash;
  List<BigInt> _bestTipBatchTransactions = const [];

  // Cached rewards data
  int? _producedInEpoch;
  int? _winsInEpoch;
  BigInt? _earnedSoFar;
  BigInt? _expectedTotal;
  BigInt? _rewardPerBlock;

  Timer? _autoTimer;
  late final TabController _tabController;
  DateTime? _lastChecked;

  // Sync speed tracking
  int? _previousBlockHeight;
  DateTime? _previousHeightCheck;
  double? _blocksPerSecond;

  // Collapsible section states
  bool _isBlockchainExpanded = false;
  bool _isRecentBlocksExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer provider modifications until after first frame to avoid
    // "modify provider while building" errors when navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Periodic auto-refresh every 5 seconds while this screen is alive.
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_refreshing) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _error = null; // keep content visible; show error inline
    });
    try {
      LoggingService.instance.debug('Refreshing providers', tag: 'NODE');
      // Refresh providers
      // Note: nodeStatusProvider is now derived from nodeRawStatusProvider,
      // so we only need to refresh nodeRawStatusProvider
      await ref.read(nodeRawStatusProvider.notifier).refresh();
      await ref.read(nodeMempoolProvider.notifier).refresh();
      await ref.read(nodeBlockchainProvider.notifier).refresh();
      await ref.read(nodeEpochRewardsProvider.notifier).refresh();

      // Check if still mounted after async operations
      if (!mounted) return;

      // Get the raw status for UI state
      final raw = ref.read(nodeRawStatusProvider).value;
      if (raw != null) {
        final localBestTip = raw.localBest;
        final networkBestTip = raw.networkBest;
        final displayBestTip = networkBestTip ?? localBestTip;

        if (!mounted) return;
        setState(() {
          // Calculate sync speed
          final currentHeight = localBestTip?.height;
          final now = DateTime.now();
          if (_previousBlockHeight != null &&
              _previousHeightCheck != null &&
              currentHeight != null &&
              currentHeight > _previousBlockHeight!) {
            final timeDiff = now.difference(_previousHeightCheck!).inSeconds;
            if (timeDiff > 0) {
              final blockDiff = currentHeight - _previousBlockHeight!;
              _blocksPerSecond = blockDiff / timeDiff;
            }
          }
          _previousBlockHeight = currentHeight;
          _previousHeightCheck = now;

          _peers = raw.peers;
          _currentBlockHeight = localBestTip?.height;
          _networkBestTipHeight = networkBestTip?.height;
          _bestTipGlobalSlot = displayBestTip?.globalSlot;
          _bestTipEpoch = displayBestTip?.epoch;
          try {
            _bestTipHash = displayBestTip?.hash.toString();
          } catch (e) {
            _bestTipHash = null;
          }
          _bestTipBatchTransactions = raw.bestTipBatchTransactions;
          _lastChecked = DateTime.now();

          // Cache rewards data
          final rewardsData = ref.read(nodeEpochRewardsProvider).value;
          if (rewardsData != null) {
            _producedInEpoch = rewardsData.producedInEpoch;
            _winsInEpoch = rewardsData.winsInEpoch;
            _earnedSoFar = rewardsData.earnedSoFar;
            _expectedTotal = rewardsData.expectedTotal;
            _rewardPerBlock = rewardsData.rewardPerBlock;
          }
        });
      }
    } catch (e, st) {
      LoggingService.instance
          .error('Refresh failed', tag: 'NODE', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const AppAppBar(
        title: 'Node Status',
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12,
          ),
          children: [
            if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error', style: TextStyle(color: colorScheme.error)),
                  const SizedBox(height: 6),
                  Text(_error!, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                ],
              ),

            // OVERVIEW Section (includes Synchronization details)
            _buildOverviewSection(context, ref.watch(nodeStatusProvider).value),
            const SizedBox(height: 18),

            // BLOCKCHAIN Section (collapsible, without Recent Blocks)
            _buildBlockchainSection(context),
            const SizedBox(height: 18),

            // RECENT BLOCKS Section (collapsible, separate card)
            _buildRecentBlocksSection(context),
          ],
        ),
      ),
    );
  }

  // Helper method to build diary-style card wrapper
  Widget _buildDiaryCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceBright,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colorScheme.outline.withValues(alpha: 0.2),
              offset: const Offset(1.1, 1.1),
              blurRadius: 10.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  // Helper method for section headers (unused - integrated into cards)
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Text(
      title,
      style: theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 18,
          letterSpacing: 0.5,
          color: colorScheme.onSurfaceVariant),
    );
  }

  // Helper method for horizontal divider
  Widget _buildDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }

  Widget _buildOverviewSection(
      BuildContext context, NodeStatus? statusFromProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = ref.watch(syncStatusProvider);
    final isSynced = sync.isSynced;

    // Calculate sync percentage
    final currentHeight =
        statusFromProvider?.localBestHeight ?? _currentBlockHeight ?? 0;
    final networkHeight = statusFromProvider?.networkBestHeight ??
        _networkBestTipHeight ??
        currentHeight;
    final syncPercentage =
        networkHeight > 0 ? (currentHeight / networkHeight) : sync.progress;

    // Peer status
    int connectedPeers;
    int totalPeers;
    if (statusFromProvider != null) {
      connectedPeers = statusFromProvider.connectedPeers;
      totalPeers = statusFromProvider.totalPeers;
    } else {
      final raw = ref.watch(nodeRawStatusProvider).value;
      if (raw != null) {
        int c = 0;
        for (final p in raw.peers) {
          if (p.connectionStatus == PeerConnectionStatus.connected) c++;
        }
        connectedPeers = c;
        totalPeers = raw.peers.length;
      } else {
        connectedPeers = 0;
        totalPeers = 0;
      }
    }
    final peerHealthy = connectedPeers > 0 && connectedPeers == totalPeers;
    final accentColor = isSynced ? colorScheme.tertiary : colorScheme.primary;

    return _buildDiaryCard(
      context: context,
      children: [
        _buildSectionHeader(context, 'Overview'),
        const SizedBox(height: 12),

        // Status line
        Row(
          children: [
            Icon(
              isSynced ? Icons.check_circle : Icons.sync,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              isSynced ? 'Synced' : 'Syncing',
              style: theme.textTheme.titleMedium!
                  .copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.18)
                  .copyWith(
                    color: accentColor,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: theme.textTheme.bodyMedium!
                  .copyWith(fontSize: 14, letterSpacing: 0.2)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Block $currentHeight / $networkHeight',
                style: theme.textTheme.bodyMedium!
                    .copyWith(fontSize: 14, letterSpacing: 0.2),
              ),
            ),
            Text(
              '${(syncPercentage * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.titleMedium!
                  .copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.18)
                  .copyWith(
                    color: accentColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: syncPercentage,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            minHeight: 8,
          ),
        ),

        // Sync speed info
        if (!isSynced && _blocksPerSecond != null && _blocksPerSecond! > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.speed, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${_blocksPerSecond!.toStringAsFixed(1)} blocks/sec',
                style: theme.textTheme.bodySmall!
                    .copyWith(
                        fontSize: 12,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurfaceVariant)
                    .copyWith(
                      fontSize: 11,
                    ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule,
                  size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'ETA: ${_calculateETA(currentHeight, networkHeight, _blocksPerSecond!)}',
                style: theme.textTheme.bodySmall!
                    .copyWith(
                        fontSize: 12,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurfaceVariant)
                    .copyWith(
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ],

        // Horizontal divider before sync details
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildDivider(),
        ),

        // Sync Details subsection
        _buildSyncDetailsSubsection(context),

        // Horizontal divider after sync details
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildDivider(),
        ),

        // Peers and Epoch info row
        Row(
          children: [
            Expanded(
              child: _buildCompactInfoCard(
                context,
                icon: Icons.people,
                label: 'Peers',
                value: '$connectedPeers/$totalPeers',
                subtitle: peerHealthy ? 'All connected' : 'Some offline',
                color: peerHealthy
                    ? colorScheme.tertiary
                    : colorScheme.error.withValues(alpha: 0.7),
                colorScheme: colorScheme,
                onTap: () {
                  final raw = ref.read(nodeRawStatusProvider).value;
                  final peers =
                      (raw?.peers.isNotEmpty == true) ? raw!.peers : _peers;
                  if (peers.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NodePeersScreen(peers: peers),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactInfoCard(
                context,
                icon: Icons.access_time,
                label: 'Epoch',
                value: '${_bestTipEpoch ?? 'N/A'}',
                subtitle: 'Slot ${_bestTipGlobalSlot ?? 'N/A'}',
                color: colorScheme.primary,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),

        // Horizontal divider before Produced blocks and Won slots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildDivider(),
        ),

        // Produced blocks and Won Slots row
        Row(
          children: [
            Expanded(
              child: _buildCompactInfoCard(
                context,
                icon: Icons.check_circle_outline,
                label: 'Produced Blocks',
                value: '', // Value shown only in subtitle to avoid repetition
                subtitle: '${() {
                  final produced = ref
                          .watch(nodeEpochRewardsProvider)
                          .value
                          ?.producedInEpoch ??
                      _producedInEpoch ??
                      0;
                  return produced == 1 ? '1 block' : '$produced blocks';
                }()}',
                color: colorScheme.tertiary, // Match Peers icon color
                colorScheme: colorScheme,
                onTap: () => context.push('/main/node/produced-blocks'),
                useGradient: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactInfoCard(
                context,
                icon: Icons.emoji_events,
                label: 'Won Slots',
                value: '', // Value shown only in subtitle to avoid repetition
                subtitle: '${() {
                  final wonSlots =
                      ref.watch(nodeEpochRewardsProvider).value?.winsInEpoch ??
                          _winsInEpoch ??
                          0;
                  return wonSlots == 1 ? '1 slot' : '$wonSlots slots';
                }()}',
                color: const Color(
                    0xFFF9A825), // Darker golden yellow for better readability
                colorScheme: colorScheme,
                onTap: () => context.push('/main/node/won-slots'),
                useGradient: false,
              ),
            ),
          ],
        ),

        if (_lastChecked != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatLastChecked(),
              style: theme.textTheme.bodySmall!
                  .copyWith(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
    bool useGradient = false,
  }) {
    final theme = Theme.of(context);

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: useGradient ? null : colorScheme.surfaceContainerLow,
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    // Glassmorphism: white overlay blended with color
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.04),
                      color.withValues(alpha: 0.08),
                    ),
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.02),
                      color.withValues(alpha: 0.04),
                    ),
                  ],
                )
              : null,
          border: useGradient
              ? Border.all(
                  color:
                      color.withValues(alpha: 0.15), // Semi-transparent border
                  width: 1.0,
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: useGradient
              ? [
                  // Soft glow with color tint
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 8.0,
                    spreadRadius: 0,
                  ),
                  // Subtle depth shadow
                  BoxShadow(
                    color: colorScheme.outline.withValues(alpha: 0.08),
                    offset: const Offset(0, 1),
                    blurRadius: 3.0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 4.0,
                  )
                ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(
                  alpha: 0.20), // Icon background for glassmorphism
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall!
                          .copyWith(
                              fontSize: 12,
                              letterSpacing: 0.2,
                              color: colorScheme.onSurfaceVariant)
                          .copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium!
                          .copyWith(fontSize: 14, letterSpacing: 0.2)
                          .copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall!
                      .copyWith(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurfaceVariant)
                      .copyWith(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          // Show chevron arrow for clickable cards
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: color.withValues(alpha: 0.5),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: card,
      );
    }

    return card;
  }

  // Sync Details subsection - shown within Overview card
  Widget _buildSyncDetailsSubsection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final raw = ref.watch(nodeRawStatusProvider).value;
    final fetchProgress = raw?.fetchProgress;
    final applyProgress = raw?.applyProgress;

    // Calculate percentages
    double fetchPercentage = 0.0;
    double applyPercentage = 0.0;

    if (fetchProgress != null) {
      final total =
          fetchProgress.idle + fetchProgress.pending + fetchProgress.done;
      if (total > BigInt.zero) {
        fetchPercentage =
            (fetchProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        fetchPercentage = 100.0;
      }
    } else {
      fetchPercentage = 100.0;
    }

    if (applyProgress != null) {
      final total =
          applyProgress.idle + applyProgress.pending + applyProgress.done;
      if (total > BigInt.zero) {
        applyPercentage =
            (applyProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        applyPercentage = 100.0;
      }
    } else {
      applyPercentage = 100.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subsection header
        Text(
          'Sync Details',
          style: theme.textTheme.bodySmall!
              .copyWith(
                  fontSize: 12,
                  letterSpacing: 0.2,
                  color: colorScheme.onSurfaceVariant)
              .copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
        ),
        const SizedBox(height: 12),

        // Horizontal row of circular progress cards
        Row(
          children: [
            // Fetch progress card
            Expanded(
              child: _buildCircularProgressCard(
                context: context,
                label: 'Fetch Blocks',
                percentage: fetchPercentage,
                color: fetchPercentage >= 100.0
                    ? colorScheme.tertiary
                    : (colorScheme.brightness == Brightness.light
                        ? colorScheme.primary
                        : colorScheme.primaryFixed),
                done: fetchProgress?.done,
                pending: fetchProgress?.pending,
                idle: fetchProgress?.idle,
              ),
            ),
            const SizedBox(width: 12),
            // Apply progress card
            Expanded(
              child: _buildCircularProgressCard(
                context: context,
                label: 'Apply Blocks',
                percentage: applyPercentage,
                color: applyPercentage >= 100.0
                    ? colorScheme.tertiary
                    : colorScheme.secondary,
                done: applyProgress?.done,
                pending: applyProgress?.pending,
                idle: applyProgress?.idle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to build circular progress card with row layout
  Widget _buildCircularProgressCard({
    required BuildContext context,
    required String label,
    required double percentage,
    required Color color,
    BigInt? done,
    BigInt? pending,
    BigInt? idle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: colorScheme.outline.withValues(alpha: 0.1),
                offset: const Offset(0.5, 0.5),
                blurRadius: 4.0)
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular progress indicator (left side)
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.surface,
                  ),
                ),
                // Progress circle
                CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                // Percentage text in center (smaller)
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium!
                      .copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.18)
                      .copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Content on right side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                Text(
                  label,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontSize: 14, letterSpacing: 0.2)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                ),
                // Stats (if available)
                if (done != null && pending != null && idle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Done: $done',
                    style: theme.textTheme.bodySmall!
                        .copyWith(
                            fontSize: 12,
                            letterSpacing: 0.2,
                            color: colorScheme.onSurfaceVariant)
                        .copyWith(
                          fontSize: 10,
                        ),
                  ),
                  Text(
                    'Pending: $pending',
                    style: theme.textTheme.bodySmall!
                        .copyWith(
                            fontSize: 12,
                            letterSpacing: 0.2,
                            color: colorScheme.onSurfaceVariant)
                        .copyWith(
                          fontSize: 10,
                        ),
                  ),
                  Text(
                    'Idle: $idle',
                    style: theme.textTheme.bodySmall!
                        .copyWith(
                            fontSize: 12,
                            letterSpacing: 0.2,
                            color: colorScheme.onSurfaceVariant)
                        .copyWith(
                          fontSize: 10,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockchainSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final raw = ref.watch(nodeRawStatusProvider).value;
    final bestTipUi = ref.watch(bestTipUiProvider).value;
    final mempoolAsync = ref.watch(nodeMempoolProvider);
    final mempoolUi = ref.watch(mempoolUiProvider).value;
    final rewards = ref.watch(nodeEpochRewardsProvider).value;

    // Best Tip data
    final height = raw?.networkBestHeight ??
        raw?.localBestHeight ??
        _networkBestTipHeight ??
        _currentBlockHeight ??
        bestTipUi?.snapshot?.height;
    final hash = raw?.bestTipHash ?? _bestTipHash ?? bestTipUi?.snapshot?.hash;
    final displayHash = () {
      if (hash == null || hash.isEmpty) return 'N/A';
      final h = hash;
      final head = h.length >= 6 ? h.substring(0, 6) : h;
      final tail = h.length >= 6 ? h.substring(h.length - 6) : '';
      return '$head…$tail';
    }();

    final batches = (() {
      if (raw?.bestTipBatchTransactions.isNotEmpty == true) {
        return raw!.bestTipBatchTransactions;
      }
      if (_bestTipBatchTransactions.isNotEmpty) {
        return _bestTipBatchTransactions;
      }
      return (bestTipUi?.snapshot?.batchTransactions ?? [])
          .map((e) => BigInt.parse(e))
          .toList();
    }());

    final batchSummary = batches.isNotEmpty
        ? batches
            .asMap()
            .entries
            .map((e) => '${e.key + 1}: ${e.value}')
            .join('  •  ')
        : 'None';

    // Mempool data
    String mempoolCount = '0';
    String mempoolOrphans = '0';
    String mempoolSize = '0B';

    mempoolAsync.whenData((mempool) {
      if (mempool != null) {
        mempoolCount = mempool.count.toString();
        mempoolOrphans = mempool.orphans.toString();
        mempoolSize = _formatBytes(mempool.totalSize);
      } else if (mempoolUi?.snapshot != null) {
        final snap = mempoolUi!.snapshot!;
        mempoolCount = snap.count;
        mempoolOrphans = snap.orphans;
        mempoolSize = _formatBytes(BigInt.parse(snap.totalSize));
      }
    });

    return _buildDiaryCard(
      context: context,
      children: [
        // Header row with expand/collapse icon
        InkWell(
          onTap: () {
            setState(() {
              _isBlockchainExpanded = !_isBlockchainExpanded;
            });
          },
          child: Row(
            children: [
              Expanded(child: _buildSectionHeader(context, 'Blockchain')),
              Icon(
                _isBlockchainExpanded ? Icons.expand_less : Icons.expand_more,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),

        // Collapsible content
        if (_isBlockchainExpanded) ...[
          const SizedBox(height: 12),

          // Best Tip row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Best Tip',
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  '${_fmtInt(height)} ($displayHash)',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontSize: 14, letterSpacing: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Batches row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Batches',
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  batchSummary,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontSize: 14, letterSpacing: 0.2),
                ),
              ),
            ],
          ),

          // Horizontal divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildDivider(),
          ),

          // Mempool row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Mempool',
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  '$mempoolCount tx ($mempoolOrphans orphans)  •  $mempoolSize',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontSize: 14, letterSpacing: 0.2),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/main/node/mempool'),
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
                      'View',
                      style: theme.textTheme.bodySmall!
                          .copyWith(
                              fontSize: 12,
                              letterSpacing: 0.2,
                              color: colorScheme.onSurfaceVariant)
                          .copyWith(
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward,
                        size: 14, color: colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),

          // Horizontal divider before Earned row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildDivider(),
          ),

          // Earned row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Earned',
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  '${_formatTokenAmount(rewards?.earnedSoFar ?? _earnedSoFar ?? BigInt.zero)}  •  Expected: ${_formatTokenAmount(rewards?.expectedTotal ?? _expectedTotal ?? BigInt.zero)}',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontSize: 14, letterSpacing: 0.2),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // NEW method: Separate Recent Blocks section
  Widget _buildRecentBlocksSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchain = ref.watch(nodeBlockchainProvider).value;

    // Don't show section if no blocks available
    if (blockchain == null || blockchain.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildDiaryCard(
      context: context,
      children: [
        // Header row with expand/collapse icon
        InkWell(
          onTap: () {
            setState(() {
              _isRecentBlocksExpanded = !_isRecentBlocksExpanded;
            });
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Blocks',
                  style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
              if (!_isRecentBlocksExpanded)
                TextButton(
                  onPressed: () => context.push('/main/node/produced-blocks'),
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
                        style: theme.textTheme.bodySmall!
                            .copyWith(
                                fontSize: 12,
                                letterSpacing: 0.2,
                                color: colorScheme.onSurfaceVariant)
                            .copyWith(
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

        // Collapsible content
        if (_isRecentBlocksExpanded) ...[
          const SizedBox(height: 12),
          _buildProducedBlocksTab(context),
        ],
      ],
    );
  }

  String _formatBytes(BigInt bytes) {
    final b = bytes.toInt();
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // ignore: unused_element
  Color _statusColor(ThemeData theme, PeerConnectionStatus s) {
    final colorScheme = theme.colorScheme;
    switch (s) {
      case PeerConnectionStatus.connected:
        return colorScheme.tertiary;
      case PeerConnectionStatus.connecting:
        return colorScheme.primary;
      case PeerConnectionStatus.disconnected:
        return colorScheme.error;
      case PeerConnectionStatus.disconnecting:
        return colorScheme.error.withValues(alpha: 0.7);
    }
  }

  // ignore: unused_element
  String? _peerIp(RpcPeerInfo p) {
    // Prefer address field, then connectingDetails
    final addr = _extractIpPort(p.address);
    if (addr != null) return addr;
    final det = _extractIpPort(p.connectingDetails);
    return det;
  }

  // ignore: unused_element
  String? _peerIpOnly(RpcPeerInfo p) {
    // Prefer address field, then connectingDetails
    final addr = _extractIpOnly(p.address);
    if (addr != null) return addr;
    final det = _extractIpOnly(p.connectingDetails);
    return det;
  }

  String? _extractIpPort(String? text) {
    if (text == null) return null;
    final s = text.trim();
    // Multiaddr form: /ip4/<ip>/tcp/<port>/p2p/<peerId> (or ip6/dns)
    if (s.startsWith('/')) {
      final parts = s.split('/').where((e) => e.isNotEmpty).toList();
      String? host;
      String? port;
      for (var i = 0; i < parts.length - 1; i++) {
        final t = parts[i].toLowerCase();
        if (t == 'ip4' || t == 'ip6' || t.startsWith('dns')) {
          host = parts[i + 1];
        }
        if (t == 'tcp' || t == 'udp') {
          port = i + 1 < parts.length ? parts[i + 1] : null;
        }
      }
      if (host != null && port != null) return '$host:$port';
      if (host != null) return host;
    }
    // IPv6 in brackets, include optional port
    final ipv6 = RegExp(r'\[([0-9a-fA-F:]+)\](?::\d+)?').firstMatch(s);
    if (ipv6 != null) return ipv6.group(0);
    // IPv4 with optional port
    final ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?').firstMatch(s);
    if (ipv4 != null) return ipv4.group(0);
    // Fallback: hostname:port
    final host = RegExp(r'([A-Za-z0-9.-]+(?::\d+)?)').firstMatch(s)?.group(0);
    return host;
  }

  String? _extractIpOnly(String? text) {
    if (text == null) return null;
    final s = text.trim();
    // Multiaddr form: /ip4/<ip>/tcp/<port>/p2p/<peerId> (or ip6/dns)
    if (s.startsWith('/')) {
      final parts = s.split('/').where((e) => e.isNotEmpty).toList();
      for (var i = 0; i < parts.length - 1; i++) {
        final t = parts[i].toLowerCase();
        if (t == 'ip4' || t == 'ip6' || t.startsWith('dns')) {
          return parts[i + 1];
        }
      }
    }
    // IPv6 in brackets or raw
    final ipv6Br = RegExp(r'\[([0-9a-fA-F:]+)\]').firstMatch(s);
    if (ipv6Br != null) return ipv6Br.group(0);
    final ipv6Raw = RegExp(r'\b[0-9a-fA-F:]{2,}\b').firstMatch(s);
    if (ipv6Raw != null && ipv6Raw.group(0)!.contains(':')) {
      return ipv6Raw.group(0);
    }
    // IPv4 only
    final ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})').firstMatch(s);
    if (ipv4 != null) return ipv4.group(1);
    // Hostname only
    final hostOnly = RegExp(r'^([A-Za-z0-9.-]+)').firstMatch(s)?.group(1);
    return hostOnly;
  }

  String _formatUtc(BigInt value) {
    // Heuristic to interpret epoch unit from digit length
    final digits = value.toString().length;
    BigInt ms;
    if (digits >= 19) {
      // nanoseconds -> ms
      ms = value ~/ BigInt.from(1000000);
    } else if (digits >= 16) {
      // microseconds -> ms
      ms = value ~/ BigInt.from(1000);
    } else if (digits >= 13) {
      // already milliseconds
      ms = value;
    } else {
      // seconds -> ms
      ms = value * BigInt.from(1000);
    }
    final millis = ms.toInt();
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    // ISO 8601 UTC
    return dt.toIso8601String();
  }

  // ignore: unused_element
  String _formatTimeAgo(BigInt value) {
    // Convert using the same unit heuristic as _formatUtc
    final iso = _formatUtc(value);
    late final DateTime dt;
    try {
      dt = DateTime.parse(iso).toUtc();
    } catch (_) {
      return 'just now';
    }
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 2) return 'a minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 2) return 'an hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 2) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks week${weeks > 1 ? 's' : ''} ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';
    final years = (diff.inDays / 365).floor();
    return '$years year${years > 1 ? 's' : ''} ago';
  }

  String _fmtInt(int? v) => v == null ? 'N/A' : v.toString();

  String _formatTokenAmount(BigInt amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount.toInt());
  }

  String _formatLastChecked() {
    if (_lastChecked == null) return '';

    final now = DateTime.now();
    final checked = _lastChecked!;

    // Format time as HH:MM:SS
    final hour = checked.hour.toString().padLeft(2, '0');
    final minute = checked.minute.toString().padLeft(2, '0');
    final second = checked.second.toString().padLeft(2, '0');

    // Check if it's today
    final isToday = now.year == checked.year &&
        now.month == checked.month &&
        now.day == checked.day;

    if (isToday) {
      return 'Last checked at $hour:$minute:$second';
    } else {
      // Show date if not today
      final month = checked.month.toString().padLeft(2, '0');
      final day = checked.day.toString().padLeft(2, '0');
      return 'Last checked on ${checked.year}-$month-$day at $hour:$minute:$second';
    }
  }

  String _calculateETA(int current, int target, double blocksPerSec) {
    if (blocksPerSec <= 0 || current >= target) return 'N/A';

    final blocksRemaining = target - current;
    final secondsRemaining = (blocksRemaining / blocksPerSec).ceil();

    if (secondsRemaining < 60) {
      return '~${secondsRemaining}s';
    } else if (secondsRemaining < 3600) {
      final minutes = (secondsRemaining / 60).ceil();
      return '~$minutes min';
    } else if (secondsRemaining < 86400) {
      final hours = (secondsRemaining / 3600).ceil();
      return '~$hours hr';
    } else {
      final days = (secondsRemaining / 86400).ceil();
      return '~$days day${days > 1 ? 's' : ''}';
    }
  }

  Widget _buildProducedBlocksTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchain = ref.watch(nodeBlockchainProvider).value;
    final raw = ref.watch(nodeRawStatusProvider).value;
    final rewards = ref.watch(nodeEpochRewardsProvider).value;

    if (blockchain == null || blockchain.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No produced blocks available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Display blocks from the blockchain
    final blocks = blockchain.items.take(10).toList();
    final bestTipSlot = raw?.globalSlot ?? _bestTipGlobalSlot;
    final rewardPerBlock =
        rewards?.rewardPerBlock ?? _rewardPerBlock ?? BigInt.zero;

    return Column(
      children: blocks.asMap().entries.map((entry) {
        final block = entry.value;
        final isBestTip =
            bestTipSlot != null && block.globalSlot == bestTipSlot;

        String blockHash;
        try {
          blockHash = block.hash.toString();
        } catch (e) {
          blockHash = 'N/A';
        }

        String producerPubkey;
        try {
          producerPubkey = block.producerPubkey;
        } catch (e) {
          producerPubkey = '';
        }

        return _ProducedBlockItem(
          blockNumber: block.height,
          epoch: block.epoch,
          globalSlot: block.globalSlot,
          hash: blockHash,
          producerPubkey: producerPubkey,
          batches: block.batches.length,
          isBestTip: isBestTip,
          reward: rewardPerBlock,
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}

class _ProducedBlockItem extends StatelessWidget {
  final int blockNumber;
  final int epoch;
  final int globalSlot;
  final String hash;
  final String producerPubkey;
  final int batches;
  final bool isBestTip;
  final BigInt reward;

  const _ProducedBlockItem({
    required this.blockNumber,
    required this.epoch,
    required this.globalSlot,
    required this.hash,
    required this.producerPubkey,
    required this.batches,
    required this.isBestTip,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Shorten the hash
    final shortHash = _shortenHashStatic(hash);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBestTip
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerLow,
        border:
            isBestTip ? Border.all(color: colorScheme.primary, width: 2) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(
            Icons.check_circle,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with best tip badge
                Row(
                  children: [
                    Text(
                      'Block #$blockNumber',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isBestTip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BEST TIP',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Slot and batches info
                Text(
                  'Slot #$globalSlot • ${batches == 1 ? '1 batch' : '$batches batches'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),

                // Hash
                Text(
                  'Hash: $shortHash',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),

                // Producer pubkey if available
                if (producerPubkey.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Producer: ${_shortenHashStatic(producerPubkey, head: 8, tail: 8)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Reward
          if (reward > BigInt.zero)
            Text(
              '+${_formatTokenAmountStatic(reward)} TKN',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.tertiary,
              ),
            ),
        ],
      ),
    );
  }

  static String _shortenHashStatic(String hash, {int head = 6, int tail = 6}) {
    if (hash == 'N/A' || hash.isEmpty) return hash;
    if (hash.length <= head + tail + 3) return hash;
    return '${hash.substring(0, head)}...${hash.substring(hash.length - tail)}';
  }

  static String _formatTokenAmountStatic(BigInt amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount.toInt());
  }
}

class SwapPlaceholder extends StatelessWidget {
  const SwapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.currency_exchange, size: 48),
              const SizedBox(height: 12),
              Text(l10n.swap, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.tokenSwap,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPlaceholder extends StatelessWidget {
  const StatusPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hub, size: 48),
              const SizedBox(height: 12),
              Text(l10n.node, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.nodeStatus,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardsPlaceholder extends StatelessWidget {
  const RewardsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_giftcard, size: 48),
              const SizedBox(height: 12),
              Text(l10n.rewards, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.rewardsAchievements,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
