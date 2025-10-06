import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;
import 'node_peers_screen.dart';

class NodeStatusScreen extends StatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  State<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends State<NodeStatusScreen>
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
  RpcListMempoolResp? _mempoolData;

  Timer? _autoTimer;
  late final TabController _tabController;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
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
      Log.d('NODE', 'Fetching status');
      final status = await RustBackendService.instance.getStatus();
      final mempool = await RustBackendService.instance.listMempool();
      if (status != null) {
        try {
          final Map<String, dynamic> statusMap = {};

          // Add peers
          try {
            statusMap['peers'] = status.peers.map((p) => {
              'peerId': p.peerId.toString(),
              'address': p.address,
              'connectionStatus': p.connectionStatus.toString(),
              'connectingDetails': p.connectingDetails,
              'incoming': p.incoming,
              'time': p.time.toString(),
            }).toList();
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
                'batches': bestTip.batches.map((b) => {
                  'transactions': b.transactions.toString(),
                }).toList(),
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
        _mempoolData = mempool;
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
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error',
                      style: TextStyle(color: colorScheme.error)),
                  const SizedBox(height: 6),
                  Text(_error!, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                ],
              ),

            // Hero Status Card
            _buildHeroStatusCard(context),
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

            // Activity Section with Tabs
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Scheduled Slots')),
                ButtonSegment(value: 1, label: Text('Produced Blocks')),
              ],
              selected: {_tabController.index},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _tabController.index = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tab content
            if (_tabController.index == 0)
              // Scheduled Slots Tab
              Column(
                children: [
                  _SlotItem(
                    icon: Icons.upcoming,
                    title: 'Slot in 1h 5m',
                    subtitle: 'Slot #12345',
                    iconColor: Colors.orange,
                    reward: '+0.5 COINS',
                    slotNumber: 12345,
                  ),
                  const SizedBox(height: 8),
                  _SlotItem(
                    icon: Icons.schedule,
                    title: 'Slot in 3h 20m',
                    subtitle: 'Slot #12350',
                    iconColor: Colors.blue,
                    reward: '+0.5 COINS',
                    slotNumber: 12350,
                  ),
                ],
              )
            else
              // Produced Blocks Tab
              Column(
                children: [
                  _ProducedBlockItem(
                    title: 'Block #1234',
                    subtitle: '2 hours ago',
                    reward: '+0.5 COINS',
                    blockNumber: 1234,
                  ),
                  const SizedBox(height: 8),
                  _ProducedBlockItem(
                    title: 'Block #1233',
                    subtitle: '4 hours ago',
                    reward: '+0.5 COINS',
                    blockNumber: 1233,
                  ),
                ],
              ),
            ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSynced = _isSynced();
    final statusText = _getSyncStatus();

    // Determine status color
    Color statusColor;
    Color statusTextColor;

    if (isSynced) {
      statusColor = colorScheme.tertiaryContainer;
      statusTextColor = colorScheme.onTertiaryContainer;
    } else if (statusText == 'Syncing') {
      statusColor = colorScheme.secondaryContainer;
      statusTextColor = colorScheme.onSecondaryContainer;
    } else {
      statusColor = colorScheme.errorContainer;
      statusTextColor = colorScheme.onErrorContainer;
    }

    // Calculate sync percentage
    final currentHeight = _currentBlockHeight ?? 0;
    final networkHeight = _networkBestTipHeight ?? currentHeight;
    final syncPercentage = networkHeight > 0 ? (currentHeight / networkHeight) : 1.0;

    // Peer status
    int connectedPeers = 0;
    for (final p in _peers) {
      if (p.connectionStatus == PeerConnectionStatus.connected) {
        connectedPeers++;
      }
    }
    final totalPeers = _peers.length;
    final peerHealthy = connectedPeers > 0 && connectedPeers == totalPeers;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      statusText.toUpperCase(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: statusTextColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    icon: Icon(Icons.refresh, color: statusTextColor, size: 16),
                    onPressed: _refreshing ? null : _refresh,
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // Build info button
                  IconButton(
                    icon: Icon(Icons.info_outline, color: statusTextColor, size: 16),
                    onPressed: _showBuildInfoDialog,
                    tooltip: 'Build Info',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Last checked timestamp
            if (_lastChecked != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatLastChecked(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Block height progress
            Text(
              'Block Height',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currentHeight / $networkHeight',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${(syncPercentage * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: syncPercentage,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),

            const SizedBox(height: 12),

            // Quick info section
            Row(
              children: [
                // Peers chip (clickable)
                _buildInfoChip(
                  context,
                  icon: Icons.people,
                  label: '$connectedPeers/$totalPeers Peers',
                  color: peerHealthy ? colorScheme.tertiary : colorScheme.error,
                  onTap: _peers.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NodePeersScreen(peers: _peers),
                            ),
                          );
                        },
                ),
                const SizedBox(width: 16),
                // Epoch/Slot info (not clickable)
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      _formatEpochInline(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      );
    }

    return chip;
  }

  Widget _buildSyncProgressCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fetchProgress = _fetchProgress;
    final applyProgress = _applyProgress;

    // Calculate percentages
    double fetchPercentage = 0.0;
    double applyPercentage = 0.0;

    if (fetchProgress != null) {
      final total = fetchProgress.idle + fetchProgress.pending + fetchProgress.done;
      if (total > BigInt.zero) {
        fetchPercentage = (fetchProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        // If total is zero (no work), consider it 100% complete
        fetchPercentage = 100.0;
      }
    } else {
      // If no progress data, consider it 100% complete
      fetchPercentage = 100.0;
    }

    if (applyProgress != null) {
      final total = applyProgress.idle + applyProgress.pending + applyProgress.done;
      if (total > BigInt.zero) {
        applyPercentage = (applyProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        // If total is zero (no work), consider it 100% complete
        applyPercentage = 100.0;
      }
    } else {
      // If no progress data, consider it 100% complete
      applyPercentage = 100.0;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Sync Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Block Fetching
            Text(
              'Block Fetching (${fetchPercentage.toStringAsFixed(1)}%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: fetchPercentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                fetchPercentage >= 100.0 ? Colors.green : Colors.grey[600]!,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            if (fetchProgress != null)
              Text(
                '(done: ${fetchProgress.done}, pending: ${fetchProgress.pending}, idle: ${fetchProgress.idle})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 16),

            // Block Application
            Text(
              'Block Application (${applyPercentage.toStringAsFixed(1)}%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: applyPercentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                applyPercentage >= 100.0 ? Colors.green : Colors.grey[600]!,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            if (applyProgress != null)
              Text(
                '(done: ${applyProgress.done}, pending: ${applyProgress.pending}, idle: ${applyProgress.idle})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Best Tip',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Height and Hash on same line
            Text(
              'Height: ${_fmtInt(_networkBestTipHeight ?? _currentBlockHeight)} (${_bestTipHashDisplay()})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Batches section with breakdown
            if (_bestTipBatchTransactions.isNotEmpty) ...[
              Text(
                'Batches (${_bestTipBatchTransactions.length} total)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ..._bestTipBatchTransactions.asMap().entries.map((entry) {
                final batchIndex = entry.key + 1;
                final txCount = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Batch $batchIndex',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$txCount trans.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              Text(
                'No batches',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
    final mempool = _mempoolData;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Mempool Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (mempool == null)
              Text(
                'Loading...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              // Summary row
              Row(
                children: [
                  _MempoolStat(
                    label: 'Count',
                    value: mempool.count.toString(),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 16),
                  _MempoolStat(
                    label: 'Orphans',
                    value: mempool.orphans.toString(),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 16),
                  _MempoolStat(
                    label: 'Total Size',
                    value: _formatBytes(mempool.totalSize),
                    colorScheme: colorScheme,
                  ),
                ],
              ),

              if (mempool.entries.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Transaction list
                ...mempool.entries.take(5).map((tx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        // TODO: Navigate to transaction details
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatTxHash(tx.id.toString()),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _TxDetailChip(
                                  icon: Icons.currency_exchange,
                                  label: 'Fee: ${tx.fee}',
                                  colorScheme: colorScheme,
                                ),
                                const SizedBox(width: 8),
                                _TxDetailChip(
                                  icon: Icons.input,
                                  label: 'In: ${tx.inputs.length}',
                                  colorScheme: colorScheme,
                                ),
                                const SizedBox(width: 8),
                                _TxDetailChip(
                                  icon: Icons.output,
                                  label: 'Out: ${tx.outputs.length}',
                                  colorScheme: colorScheme,
                                ),
                                const SizedBox(width: 8),
                                _TxDetailChip(
                                  icon: Icons.data_usage,
                                  label: '${tx.sizeBytes}B',
                                  colorScheme: colorScheme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (mempool.entries.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        '+${mempool.entries.length - 5} more transactions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'No transactions in mempool',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
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

  String _getSyncStatus() {
    final currentHeight = _currentBlockHeight;
    final bestTipHeight = _networkBestTipHeight;

    if (currentHeight == null || bestTipHeight == null) {
      // Check if we're actually synced based on progress data
      if (_isSynced()) {
        return 'Synced & Healthy';
      }
      return 'Awaiting Sync';
    }

    if (currentHeight >= bestTipHeight) {
      return 'Synced & Healthy';
    }

    return 'Syncing';
  }

  String _formatEpochInline() {
    final slot = _bestTipGlobalSlot;
    final epoch = _bestTipEpoch;
    if (epoch == null || slot == null) return 'N/A';
    return 'Epoch $epoch • Slot $slot';
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

  String _bestTipHashDisplay() {
    final hash = _bestTipHash;
    if (hash == null || hash.isEmpty) return 'N/A';
    return _shortenMid(hash, head: 10, tail: 10);
  }

  void _showBuildInfoDialog() {
    final env = rust.buildEnv();
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

class _SlotItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final String reward;
  final int slotNumber;

  const _SlotItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.reward,
    required this.slotNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: iconColor.withValues(alpha: 0.2),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          reward,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}

class _ProducedBlockItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String reward;
  final int blockNumber;

  const _ProducedBlockItem({
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.blockNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.check_circle,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          reward,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.tertiary,
          ),
        ),
      ),
    );
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
