import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/blockchain_timing.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/produced_block_card.dart';
import 'package:crypto_mobile_app/core/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'node_peers_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';

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

  // Cached rewards data
  int? _producedInEpoch;
  int? _winsInEpoch;
  BigInt? _rewardPerBlock;

  Timer? _autoTimer;
  late final TabController _tabController;
  DateTime? _lastChecked;

  // Collapsible section states
  bool _isRecentBlocksExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer provider modifications until after first frame to avoid
    // "modify provider while building" errors when navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Periodic auto-refresh every 3 seconds while this screen is alive.
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
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
      // Refresh providers
      // Note: nodeStatusProvider is now derived from nodeRawStatusProvider,
      // so we only need to refresh nodeRawStatusProvider
      await ref.read(nodeRawStatusProvider.notifier).refresh();
      // ignore: unused_result
      ref.refresh(nodeMempoolProvider.future);
      // ignore: unused_result
      ref.refresh(nodeBlockchainProvider.future);
      // ignore: unused_result
      ref.refresh(nodeEpochRewardsProvider.future);

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
          _peers = raw.peers;
          _currentBlockHeight = localBestTip?.height;
          _networkBestTipHeight = networkBestTip?.height;
          _bestTipGlobalSlot = displayBestTip?.globalSlot;
          _bestTipEpoch = displayBestTip?.epoch;
          _lastChecked = DateTime.now();

          // Cache rewards data
          final rewardsData = ref.read(nodeEpochRewardsProvider).value;
          if (rewardsData != null) {
            _producedInEpoch = rewardsData.producedInEpoch;
            _winsInEpoch = rewardsData.winsInEpoch;
            _rewardPerBlock = rewardsData.rewardPerBlock;
          }
        });
      }
    } on StateError catch (e, st) {
      // Happens if a late timer tick fires after disposal; just log quietly.
      LoggingService.instance
          .debug('Skipped refresh on disposed node screen', tag: 'NODE');
      LoggingService.instance
          .debug('StateError during refresh: $e', tag: 'NODE');
      LoggingService.instance.debug('Stack trace: $st', tag: 'NODE');
      return;
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
      height: 1,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }

  // Helper method to build Node ID row with copy functionality
  Widget _buildNodeIdRow(BuildContext context, String peerId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortened = _shortenMid(peerId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Node ID: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              shortened,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: peerId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Node ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy full Node ID',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
      BuildContext context, NodeStatus? statusFromProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = ref.watch(syncStatusProvider);
    final isSynced = sync.isSynced;

    // Calculate sync percentage - now based on applied blocks progress from sync status
    final syncPercentage = sync.progress;

    // Determine what to display for block counts
    String blockDisplayText;
    if (sync.isConnecting) {
      // Don't show block count when connecting
      blockDisplayText = '';
    } else if (sync.appliedBlocks != null && sync.targetBlocks != null) {
      // Use applied blocks data
      final appliedStr = _formatBigIntStatic(sync.appliedBlocks!);
      final targetStr = _formatBigIntStatic(sync.targetBlocks!);
      blockDisplayText = 'Block $appliedStr / $targetStr';
    } else {
      // Fallback to height-based display
      final currentHeight =
          statusFromProvider?.localBestHeight ?? _currentBlockHeight ?? 0;
      final networkHeight = statusFromProvider?.networkBestHeight ??
          _networkBestTipHeight ??
          currentHeight;
      blockDisplayText = 'Block $currentHeight / $networkHeight';
    }

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

    // Determine status display based on connection state
    final IconData statusIcon;
    final String statusLabel;
    final Color accentColor;

    if (sync.isConnecting) {
      statusIcon = Icons.hourglass_empty;
      statusLabel = 'Connecting';
      accentColor = colorScheme.outline;
    } else if (isSynced) {
      statusIcon = Icons.check_circle;
      statusLabel = 'Synced';
      accentColor = colorScheme.tertiary;
    } else {
      statusIcon = Icons.sync;
      statusLabel = 'Syncing';
      accentColor = colorScheme.primary;
    }

    return _buildDiaryCard(
      context: context,
      children: [
        _buildSectionHeader(context, 'Overview'),
        const SizedBox(height: 12),

        // Status line
        Row(
          children: [
            Icon(
              statusIcon,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              statusLabel,
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
                blockDisplayText,
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
            const SizedBox(width: 6),
            Expanded(
              child: _buildCompactInfoCard(
                context,
                icon: Icons.access_time,
                label: 'Epoch',
                value: '${statusFromProvider?.epoch ?? _bestTipEpoch ?? 'N/A'}',
                subtitle: 'Slot ${statusFromProvider?.globalSlot ?? _bestTipGlobalSlot ?? 'N/A'}',
                color: colorScheme.primary,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),

        // Node ID (peer ID) row
        if (statusFromProvider?.peerId != null) ...[
          const SizedBox(height: 12),
          _buildNodeIdRow(context, statusFromProvider!.peerId!),
        ],

        // Horizontal divider before Produced blocks and Won slots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildDivider(),
        ),

        // Produced blocks and Won Slots row
        Builder(
          builder: (context) {
            // Extract values first
            final produced =
                ref.watch(nodeEpochRewardsProvider).value?.producedInEpoch ??
                    _producedInEpoch ??
                    0;
            var wonSlots =
                ref.watch(nodeEpochRewardsProvider).value?.wonSlots?.length ??
                    ref.watch(nodeEpochRewardsProvider).value?.winsInEpoch ??
                    _winsInEpoch ??
                    0;

            // Ensure won slots is never less than produced blocks
            if (wonSlots < produced) {
              wonSlots = produced;
            }

            // Get VRF evaluator data for slots information
            final vrfEvaluator =
                ref.watch(nodeRawStatusProvider).value?.vrfEvaluator;
            final evaluatedSlots = vrfEvaluator?.evaluatedSlotsSinceStart ?? 0;
            final totalSlotsPerEpoch = BlockchainTiming.slotsPerEpoch;

            return Row(
              children: [
                Expanded(
                  child: _buildCompactInfoCard(
                    context,
                    icon: Icons.check_circle_outline,
                    label: 'Produced',
                    value:
                        '', // Value shown only in subtitle to avoid repetition
                    subtitle: produced == 1 ? '1 block' : '$produced blocks',
                    color: colorScheme.tertiary, // Match Peers icon color
                    colorScheme: colorScheme,
                    onTap: () => context.push('/main/node/produced-blocks'),
                    useGradient: false,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMultiLineInfoCard(
                    context,
                    icon: Icons.emoji_events,
                    label: 'Slots',
                    lines: [
                      'Total: ${NumberFormat('#,###').format(totalSlotsPerEpoch)}',
                      'Evaluated: ${NumberFormat('#,###').format(evaluatedSlots)}',
                      'Won: ${NumberFormat('#,###').format(wonSlots)}',
                    ],
                    color: const Color(0xFFF9A825),
                    colorScheme: colorScheme,
                    onTap: () => context.push('/main/node/won-slots'),
                    useGradient: false,
                  ),
                ),
              ],
            );
          },
        ),

        // Horizontal divider before Best Tip and Mempool
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildDivider(),
        ),

        // Best Tip and Mempool row
        Row(
          children: [
            Expanded(
              child: _buildMultiLineInfoCard(
                context,
                icon: Icons.toll,
                label: 'Best Tip',
                lines: () {
                  final raw = ref.watch(nodeRawStatusProvider).value;
                  final localBestTip = raw?.localBest;
                  final networkBestTip = raw?.networkBest;
                  final displayBestTip = networkBestTip ?? localBestTip;

                  if (displayBestTip == null) return ['N/A'];

                  final height = displayBestTip.height;
                  final hash = displayBestTip.hash.toString();
                  final producer = displayBestTip.producerPubkey;

                  final formattedHeight =
                      'Height ${NumberFormat('#,###').format(height)}';
                  final truncatedHash = hash.length > 16
                      ? '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}'
                      : hash;
                  final truncatedProducer = producer.length > 16
                      ? '${producer.substring(0, 6)}...${producer.substring(producer.length - 4)}'
                      : producer;

                  return [formattedHeight, truncatedHash, truncatedProducer];
                }(),
                color: colorScheme.tertiary,
                colorScheme: colorScheme,
                useGradient: false,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildMultiLineInfoCard(
                context,
                icon: Icons.dynamic_feed,
                label: 'Mempool',
                lines: () {
                  final mempool = ref.watch(nodeMempoolProvider).value;
                  if (mempool == null) return ['N/A'];

                  final count = mempool.count.toInt();
                  final orphans = mempool.orphans.toInt();
                  final sizeKB =
                      (mempool.totalSize.toInt() / 1024).toStringAsFixed(1);

                  return [
                    count == 1 ? '1 txn' : '$count txns',
                    '$sizeKB KB',
                    orphans == 1 ? '1 orphan' : '$orphans orphans',
                  ];
                }(),
                color: colorScheme.secondary,
                colorScheme: colorScheme,
                onTap: () => context.push('/main/node/mempool'),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                      color.withValues(alpha: 0.8), // Semi-transparent border
                  width: 1.0,
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: useGradient
              ? [
                  // Soft glow with color tint
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8.0,
                    spreadRadius: 2,
                  ),
                  // Subtle depth shadow
                ]
              : [
                  BoxShadow(
                      color: colorScheme.outline.withValues(alpha: 0.8),
                      offset: const Offset(0.5, 0.5),
                      blurRadius: 4.0)
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
            child: Icon(icon, size: 12, color: color),
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
                      style: theme.textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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

  Widget _buildMultiLineInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> lines,
    required Color color,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
    bool useGradient = false,
  }) {
    final theme = Theme.of(context);

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
          color: useGradient ? null : colorScheme.surfaceContainerLow,
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
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
                  color: color.withValues(alpha: 0.8),
                  width: 1.0,
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: useGradient
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8.0,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                      color: colorScheme.outline.withValues(alpha: 0.8),
                      offset: const Offset(0.5, 0.5),
                      blurRadius: 4.0)
                ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
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
            const SizedBox(width: 6),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: colorScheme.outline.withValues(alpha: 0.8),
                offset: const Offset(0.5, 0.5),
                blurRadius: 4.0)
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular progress indicator (left side)
          SizedBox(
            width: 50,
            height: 50,
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
                  strokeWidth: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                // Percentage text in center (smaller)
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium!.copyWith(
                      fontSize: 8, fontWeight: FontWeight.w900, color: color),
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
                  style: theme.textTheme.bodyMedium!.copyWith(
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

  static String _formatBigIntStatic(BigInt value) {
    final formatter = NumberFormat('#,###', 'en_US');
    // Convert BigInt to int for formatting (safe for reasonable block counts)
    try {
      return formatter.format(value.toInt());
    } catch (e) {
      // Fallback for very large numbers that don't fit in int
      return value.toString();
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

        return ProducedBlockCard(
          block: block,
          isBestTip: isBestTip,
          customHash: blockHash,
          customProducer: producerPubkey,
          rewardPerBlock: rewardPerBlock,
          variant: BlockCardVariant.detailed,
        );
      }).toList(),
    );
  }

  // Helper method to shorten long strings (e.g., peer IDs) for display
  String _shortenMid(String s, {int head = 8, int tail = 8}) {
    if (s.length <= head + tail + 1) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tabController.dispose();
    super.dispose();
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
