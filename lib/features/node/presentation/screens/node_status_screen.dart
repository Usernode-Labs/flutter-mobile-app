import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'node_peers_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/mempool_cache_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/best_tip_cache_provider.dart';
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
  _ProgressData? _fetchProgress;
  _ProgressData? _applyProgress;

  Timer? _autoTimer;
  late final TabController _tabController;
  DateTime? _lastChecked;

  // Sync speed tracking
  int? _previousBlockHeight;
  DateTime? _previousHeightCheck;
  double? _blocksPerSecond;

  // Soft tinted surface helper for modern light backgrounds
  Color _tint(ColorScheme scheme, Color accent, [double opacity = 0.06]) {
    return Color.alphaBlend(accent.withValues(alpha: opacity), scheme.surface);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer provider modifications until after first frame to avoid
    // "modify provider while building" errors when navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Periodic auto-refresh every 2 minutes while this screen is alive.
    _autoTimer = Timer.periodic(const Duration(minutes: 2), (_) {
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
      Log.d('NODE', 'Refreshing providers and status');
      // Refresh providers
      await ref.read(nodeStatusProvider.notifier).refresh();
      await ref.read(nodeMempoolProvider.notifier).refresh();
      await ref.read(nodeBlockchainProvider.notifier).refresh();
      await ref.read(nodeEpochRewardsProvider.notifier).refresh();
      await ref.read(nodeRawStatusProvider.notifier).refresh();

      // Also fetch raw status to derive detailed progress and local fields
      final status = await RustBackendService.instance.getStatus();
      if (status != null) {
        try {
          final Map<String, dynamic> statusMap = {};

          // Add peers
          try {
            statusMap['peers'] = status.peers
                .map((p) => {
                      'peerId': p.peerId.toString(),
                      'address': p.address,
                      'connectionStatus': p.connectionStatus.toString(),
                      'connectingDetails': p.connectingDetails,
                      'incoming': p.incoming,
                      'time': p.time.toString(),
                    })
                .toList();
          } catch (e) {
            statusMap['peers'] = 'Error: $e';
          }

          // Add blockchain info
          try {
            final blockchain = status.blockchain;
            final Map<String, dynamic> blockchainMap = {};

            try {
              final bestTip = blockchain.bestTip;
              blockchainMap['bestTip'] = {
                'height': bestTip.height,
                'epoch': bestTip.epoch,
                'globalSlot': bestTip.globalSlot,
                'hash': bestTip.hash.toString(),
                'batches': bestTip.batches
                    .map((b) => {
                          'transactions': b.transactions.toString(),
                        })
                    .toList(),
              };
            } catch (e) {
              blockchainMap['bestTip'] = 'Error: $e';
            }

            try {
              final sync = blockchain.sync;
              final blocks = sync.blocks;
              if (blocks != null) {
                blockchainMap['sync'] = {
                  'blocks': {
                    'bestTip': {
                      'height': blocks.bestTip.height,
                      'epoch': blocks.bestTip.epoch,
                      'globalSlot': blocks.bestTip.globalSlot,
                      'hash': blocks.bestTip.hash.toString(),
                    },
                    'fetchProgress': {
                      'idle': blocks.fetchProgress.idle.toString(),
                      'pending': blocks.fetchProgress.pending.toString(),
                      'done': blocks.fetchProgress.done.toString(),
                    },
                    'applyProgress': {
                      'idle': blocks.applyProgress.idle.toString(),
                      'pending': blocks.applyProgress.pending.toString(),
                      'done': blocks.applyProgress.done.toString(),
                    },
                  },
                };
              } else {
                blockchainMap['sync'] = {'blocks': null};
              }
            } catch (e) {
              blockchainMap['sync'] = 'Error: $e';
            }

            statusMap['blockchain'] = blockchainMap;
          } catch (e) {
            statusMap['blockchain'] = 'Error: $e';
          }

          final statusJson = jsonEncode(statusMap);
          Log.d('NODE', 'getStatus response: $statusJson');
        } catch (e) {
          Log.w('NODE', 'Failed to serialize status response: $e');
        }
      }
      final peers = status?.peers ?? const <RpcPeerInfo>[];
      final blockchain = status?.blockchain;
      final syncBlocks = blockchain?.sync.blocks;
      RpcStatusBlockInfo? localBestTip;
      RpcStatusBlockInfo? networkBestTip;
      try {
        localBestTip = blockchain?.bestTip;
      } catch (e) {
        localBestTip = null;
      }
      try {
        networkBestTip = syncBlocks?.bestTip;
      } catch (e) {
        networkBestTip = null;
      }
      final RpcStatusBlockInfo? displayBestTip = networkBestTip ?? localBestTip;
      List<BigInt> batchTransactions = const <BigInt>[];
      try {
        if (displayBestTip != null) {
          batchTransactions = displayBestTip.batches
              .map((info) => info.transactions)
              .toList(growable: false);
        }
      } catch (e) {
        batchTransactions = const <BigInt>[];
      }
      _ProgressData? fetchProgress;
      _ProgressData? applyProgress;
      try {
        fetchProgress = syncBlocks != null
            ? _ProgressData.fromProgress(syncBlocks.fetchProgress)
            : null;
      } catch (e) {
        fetchProgress = null;
      }
      try {
        applyProgress = syncBlocks != null
            ? _ProgressData.fromProgress(syncBlocks.applyProgress)
            : null;
      } catch (e) {
        applyProgress = null;
      }
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

        _peers = peers;
        _currentBlockHeight = localBestTip?.height;
        _networkBestTipHeight = networkBestTip?.height;
        _bestTipGlobalSlot = displayBestTip?.globalSlot;
        _bestTipEpoch = displayBestTip?.epoch;
        try {
          _bestTipHash = displayBestTip?.hash.toString();
        } catch (e) {
          _bestTipHash = null;
        }
        _bestTipBatchTransactions = batchTransactions;
        _fetchProgress = fetchProgress;
        _applyProgress = applyProgress;
        _lastChecked = DateTime.now();
      });
    } catch (e, st) {
      Log.e('NODE', 'getStatus failed', e, st);
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
      appBar: const AppAppBar(
        title: 'Node Status',
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
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

            // Hero Status Card
            _buildHeroStatusCard(context, ref.watch(nodeStatusProvider).value),
            const SizedBox(height: 16),

            // Sync Progress Card
            _buildSyncProgressCard(context),
            const SizedBox(height: 16),

            // Best Tip Card
            _buildBestTipCard(context),
            const SizedBox(height: 16),

            // Mempool Transactions Card
            _buildMempoolCard(context),
            const SizedBox(height: 24),

            // Current Epoch Summary (lightweight)
            _buildEpochSummaryCard(context),

            const SizedBox(height: 16),

            // Produced Blocks (inline preview)
            Row(
              children: [
                Text(
                  'Produced Blocks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => context.push('/main/node/produced-blocks'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProducedBlocksTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard(
      BuildContext context, NodeStatus? statusFromProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = ref.watch(syncStatusProvider);
    final isSynced = sync.isSynced;
    final statusText = sync.label;

    // Determine status color and icon
    Color statusColor;
    Color statusTextColor;
    IconData statusIcon;
    String contextualMessage;

    if (isSynced) {
      statusColor = colorScheme.tertiaryContainer;
      statusTextColor = colorScheme.onTertiaryContainer;
      statusIcon = Icons.check_circle;
      contextualMessage = 'Your node is performing optimally';
    } else if (statusText == 'Syncing') {
      statusColor = colorScheme.secondaryContainer;
      statusTextColor = colorScheme.onSecondaryContainer;
      statusIcon = Icons.sync;
      contextualMessage = 'Downloading and applying blocks...';
    } else {
      statusColor = colorScheme.errorContainer;
      statusTextColor = colorScheme.onErrorContainer;
      statusIcon = Icons.warning_amber_rounded;
      contextualMessage = 'Node requires attention';
    }

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
    final lowPeerCount = totalPeers > 0 && connectedPeers < totalPeers * 0.5;

    // Override contextual message if low peer count
    if (lowPeerCount && isSynced) {
      contextualMessage = 'Low peer count detected - check network connection';
    }

    final bg = _tint(colorScheme, colorScheme.tertiary);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // Block height progress
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSynced
                      ? Colors.green.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: isSynced ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.layers,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Block Height',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (isSynced)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 10,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Synced',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          '${(syncPercentage * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$currentHeight',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        ' / $networkHeight',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: syncPercentage,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSynced ? Colors.green : colorScheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  // Sync speed and ETA when syncing
                  if (!isSynced &&
                      _blocksPerSecond != null &&
                      _blocksPerSecond! > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.speed,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_blocksPerSecond!.toStringAsFixed(1)} blocks/sec',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentHeight < networkHeight) ...[
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ETA: ${_calculateETA(currentHeight, networkHeight, _blocksPerSecond!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Quick info section
            Row(
              children: [
                // Peers chip (clickable) - with subtitle
                Expanded(
                  child: _buildCompactInfoCard(
                    context,
                    icon: Icons.people,
                    label: 'Peers',
                    value: '$connectedPeers/$totalPeers',
                    subtitle: peerHealthy
                        ? 'All connected'
                        : lowPeerCount
                            ? 'Low count'
                            : 'Some offline',
                    color: peerHealthy
                        ? Colors.green
                        : lowPeerCount
                            ? colorScheme.error
                            : Colors.orange,
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
                const SizedBox(width: 8),
                // Epoch/Slot info card - with subtitle
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
            // Last checked timestamp
            if (_lastChecked != null) ...[
              const SizedBox(height: 10),
              Text(
                _formatLastChecked(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
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
  }) {
    final theme = Theme.of(context);

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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

  Widget _buildSyncProgressCard(BuildContext context) {
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
        // If total is zero (no work), consider it 100% complete
        fetchPercentage = 100.0;
      }
    } else {
      // If no progress data, consider it 100% complete
      fetchPercentage = 100.0;
    }

    if (applyProgress != null) {
      final total =
          applyProgress.idle + applyProgress.pending + applyProgress.done;
      if (total > BigInt.zero) {
        applyPercentage =
            (applyProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        // If total is zero (no work), consider it 100% complete
        applyPercentage = 100.0;
      }
    } else {
      // If no progress data, consider it 100% complete
      applyPercentage = 100.0;
    }

    final bg = _tint(colorScheme, colorScheme.primary, 0.04);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Sync Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Block Fetching
            Row(
              children: [
                Text(
                  'Fetch',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fetchPercentage / 100,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fetchPercentage >= 100.0 ? Colors.green : colorScheme.primary,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${fetchPercentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (fetchProgress != null)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'Done: ${fetchProgress.done}  Pending: ${fetchProgress.pending}  Idle: ${fetchProgress.idle}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Block Application
            Row(
              children: [
                Text(
                  'Apply',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: applyPercentage / 100,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        applyPercentage >= 100.0 ? Colors.green : colorScheme.primary,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${applyPercentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (applyProgress != null)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'Done: ${applyProgress.done}  Pending: ${applyProgress.pending}  Idle: ${applyProgress.idle}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestTipCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final raw = ref.watch(nodeRawStatusProvider).value;
    final bestTipUi = ref.watch(bestTipUiProvider).value;

    final bg = _tint(colorScheme, colorScheme.secondary);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Best Tip',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Height and Hash on same line
            Builder(builder: (_) {
              final height = raw?.networkBestHeight ??
                  raw?.localBestHeight ??
                  _networkBestTipHeight ??
                  _currentBlockHeight ??
                  bestTipUi?.snapshot?.height;
              final hash =
                  raw?.bestTipHash ?? _bestTipHash ?? bestTipUi?.snapshot?.hash;
              final displayHash = () {
                if (hash == null || hash.isEmpty) return 'N/A';
                final h = hash;
                final head = h.length >= 6 ? h.substring(0, 6) : h;
                final tail = h.length >= 6 ? h.substring(h.length - 6) : '';
                return '$head…$tail';
              }();
              return Text(
                'Height: ${_fmtInt(height)} ($displayHash)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              );
            }),

            const SizedBox(height: 10),

            // Batches section - inline summary
            if ((raw?.bestTipBatchTransactions.isNotEmpty ?? false) ||
                _bestTipBatchTransactions.isNotEmpty ||
                (bestTipUi?.snapshot?.batchTransactions.isNotEmpty ??
                    false)) ...[
              Builder(builder: (_) {
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

                final batchSummary = batches
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}: ${e.value} tx')
                    .join('  ');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batches (${batches.length})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      batchSummary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }),
            ] else ...[
              Text(
                'No batches',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMempoolCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mempoolAsync = ref.watch(nodeMempoolProvider);
    final mempoolUi = ref.watch(mempoolUiProvider).value;

    final bg = _tint(colorScheme, colorScheme.primary, 0.04);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: mempoolAsync.when(
          loading: () => Row(
            children: [
              Icon(Icons.pending_actions, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Mempool: Loading...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          error: (e, _) => Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Mempool: Failed to load',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          data: (mempool) {
            String count = '0';
            String orphans = '0';
            String totalSize = '0B';
            bool isStale = false;

            if (mempool != null) {
              count = mempool.count.toString();
              orphans = mempool.orphans.toString();
              totalSize = _formatBytes(mempool.totalSize);
            } else if (mempoolUi?.snapshot != null) {
              final snap = mempoolUi!.snapshot!;
              count = snap.count;
              orphans = snap.orphans;
              totalSize = _formatBytes(BigInt.parse(snap.totalSize));
              isStale = mempoolUi.isStale;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pending_actions,
                        size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mempool: $count transaction${count != '1' ? 's' : ''} ($orphans orphan${orphans != '1' ? 's' : ''})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Total Size: $totalSize',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    if (isStale) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cached',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        context.push('/main/node/mempool');
                      },
                      icon: Icon(Icons.arrow_forward,
                          size: 14, color: colorScheme.primary),
                      label: Text(
                        'View Details',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatTxHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }

  String _formatBytes(BigInt bytes) {
    final b = bytes.toInt();
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // ignore: unused_element
  Color _statusColor(ThemeData theme, PeerConnectionStatus s) {
    switch (s) {
      case PeerConnectionStatus.connected:
        return Colors.green;
      case PeerConnectionStatus.connecting:
        return Colors.amber;
      case PeerConnectionStatus.disconnected:
        return Colors.red;
      case PeerConnectionStatus.disconnecting:
        return Colors.orange;
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

  String _shortenMid(String s, {int head = 8, int tail = 8}) {
    if (s.length <= head + tail + 1) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
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

  bool _isSynced() {
    // Sync status based on current block height vs best tip block height
    // Also consider synced if heights match and no pending sync work
    final currentHeight = _currentBlockHeight;
    final bestTipHeight = _networkBestTipHeight;

    // If we don't have height info, check if sync progress is empty/complete
    if (currentHeight == null || bestTipHeight == null) {
      // Consider synced if progress is null or all zeros
      final fetchProgress = _fetchProgress;
      final applyProgress = _applyProgress;

      if (fetchProgress == null && applyProgress == null) {
        return true; // No progress data means likely synced
      }

      final fetchTotal = (fetchProgress?.idle ?? BigInt.zero) +
          (fetchProgress?.pending ?? BigInt.zero) +
          (fetchProgress?.done ?? BigInt.zero);
      final applyTotal = (applyProgress?.idle ?? BigInt.zero) +
          (applyProgress?.pending ?? BigInt.zero) +
          (applyProgress?.done ?? BigInt.zero);

      return fetchTotal == BigInt.zero && applyTotal == BigInt.zero;
    }

    // Synced if current height matches or exceeds best tip
    return currentHeight >= bestTipHeight;
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

  Widget _buildEpochSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rewardsAsync = ref.watch(nodeEpochRewardsProvider);
    final rewards = rewardsAsync.value;

    if (rewards == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            rewardsAsync.isLoading
                ? 'Loading epoch data...'
                : 'Epoch data unavailable',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: rewardsAsync.isLoading
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.error,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Epoch header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Epoch ${rewards.epoch}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Detailed breakdown
              _buildEpochStat(
                context,
                icon: Icons.production_quantity_limits,
                label: 'Blocks Produced',
                value: '${rewards.producedInEpoch}',
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _buildEpochStat(
                context,
                icon: Icons.emoji_events,
                label: 'Won Slots',
                value: '${rewards.winsInEpoch}',
                color: colorScheme.tertiary,
              ),
              const SizedBox(height: 12),
              _buildEpochStat(
                context,
                icon: Icons.attach_money,
                label: 'Reward per Block',
                value: '${rewards.rewardPerBlock}',
                color: colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              _buildEpochStat(
                context,
                icon: Icons.savings,
                label: 'Earned So Far',
                value: '${rewards.earnedSoFar}',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildEpochStat(
                context,
                icon: Icons.trending_up,
                label: 'Expected Total',
                value: '${rewards.expectedTotal}',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => context.push('/main/node/won-slots'),
                  icon: const Icon(Icons.grid_view),
                  label: const Text('View Won Slots'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEpochStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
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
    final rewardPerBlock = rewards?.rewardPerBlock ?? BigInt.zero;

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

  void _showBuildInfoDialog() {
    final env = ref.read(buildEnvProvider);
    showDialog(
      context: context,
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        final shortCommit = env.git.commitHash.length >= 7
            ? env.git.commitHash.substring(0, 7)
            : env.git.commitHash;
        return AlertDialog(
          title: const Text('Build Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: ${env.version}', style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Commit: $shortCommit', style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Branch: ${env.git.branch}', style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Commit time: ${env.git.commitTime}',
                  style: textTheme.bodyMedium),
              const Divider(height: 16),
              Text('Rustc: ${env.rustc.version} (${env.rustc.channel})',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('LLVM: ${env.rustc.llvmVersion}',
                  style: textTheme.bodyMedium),
              const Divider(height: 16),
              Text('Cargo target: ${env.cargo.target}',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Features: ${env.cargo.features}',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Opt level: ${env.cargo.optLevel}',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('Debug: ${env.cargo.isDebug}', style: textTheme.bodyMedium),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}

class _ProgressData {
  final BigInt idle;
  final BigInt pending;
  final BigInt done;

  const _ProgressData({
    required this.idle,
    required this.pending,
    required this.done,
  });

  factory _ProgressData.fromProgress(
    RpcStatusBlockchainSyncBlocksProgress progress,
  ) {
    return _ProgressData(
      idle: progress.idle,
      pending: progress.pending,
      done: progress.done,
    );
  }
}

class _MempoolStat extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _MempoolStat({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxDetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _TxDetailChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
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
                      style: theme.textTheme.bodyLarge?.copyWith(
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
              '+$reward',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
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
