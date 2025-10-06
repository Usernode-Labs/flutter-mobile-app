import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'block_details_screen.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;
import 'scheduled_slot_details_screen.dart';
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

  late final TabController _tabController;
  Timer? _autoTimer;
  Timer? _secondsTimer;
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
    // Ticker to update the "checked X seconds ago" counter
    _secondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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
            // Status Banner
            _buildStatusBanner(context),
            const SizedBox(height: 16),

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

            // Node Status Card
            _buildNodeStatusCard(context),
            const SizedBox(height: 16),

            // Sync Progress Card
            _buildSyncProgressCard(context),
            const SizedBox(height: 16),

            // Best Tip Card
            _buildBestTipCard(context),
            const SizedBox(height: 24),

              // Tabs + Slots
              Column(
                children: [
                  // Material 3 Segmented Button
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('Upcoming'),
                        icon: Icon(Icons.upcoming_outlined),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('Past Slots'),
                        icon: Icon(Icons.history),
                      ),
                    ],
                    selected: {_tabController.index},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _tabController.index = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(0),
                          children: [
                            _SlotItem(
                              icon: Icons.schedule,
                              title: 'Scheduled Slot',
                              subtitle: 'in 1h 5m',
                              iconColor: Colors.amber.shade700,
                              reward: '+100 TKN',
                              slotNumber: 112,
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(0),
                          children: [
                            _ProducedBlockItem(
                              title: 'Produced block at 112',
                              subtitle: '2h 5m ago',
                              reward: '+100 TKN',
                              blockNumber: 112,
                            ),
                            const SizedBox(height: 12),
                            _ProducedBlockItem(
                              title: 'Produced block at 113',
                              subtitle: '3h 15m ago',
                              reward: '+100 TKN',
                              blockNumber: 113,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSynced = _isSynced();
    final statusText = _getSyncStatus();

    // Determine status color based on sync state
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isSynced ? Icons.check_circle : Icons.sync,
            color: statusTextColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: theme.textTheme.titleMedium?.copyWith(
                color: statusTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: statusTextColor),
            tooltip: 'Build info',
            onPressed: _showBuildInfoDialog,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _refreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(statusTextColor),
                    ),
                  )
                : Icon(Icons.refresh, color: statusTextColor),
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeStatusCard(BuildContext context) {
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
                Icon(Icons.router, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Node Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCardRow(
              context,
              label: 'Current Block Height',
              value: _fmtInt(_currentBlockHeight),
            ),
            const SizedBox(height: 12),
            _buildCardRow(
              context,
              label: 'Epoch',
              value: _formatEpochInline(),
              valueColor: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildCardRowWithIcon(
              context,
              label: 'Connected Peers',
              value: _formatPeersInline(),
              icon: Icons.people_alt_outlined,
              onIconTap: _peers.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NodePeersScreen(peers: _peers),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _buildCardRow(
              context,
              label: 'Sync Status',
              value: _formatSyncPercentage(),
              valueColor: _isSynced() ? colorScheme.tertiary : colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
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
      }
    }

    if (applyProgress != null) {
      final total = applyProgress.idle + applyProgress.pending + applyProgress.done;
      if (total > BigInt.zero) {
        applyPercentage = (applyProgress.done.toDouble() / total.toDouble()) * 100;
      }
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
                  'Sync Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Block Fetching
            Text(
              'Block Fetching',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: fetchPercentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${fetchPercentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (fetchProgress != null) ...[
              _buildProgressDetail(context, 'Done', fetchProgress.done.toString()),
              _buildProgressDetail(context, 'Pending', fetchProgress.pending.toString()),
              _buildProgressDetail(context, 'Idle', fetchProgress.idle.toString()),
            ],

            const SizedBox(height: 16),

            // Block Application
            Text(
              'Block Application',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: applyPercentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.tertiary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${applyPercentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (applyProgress != null) ...[
              _buildProgressDetail(context, 'Done', applyProgress.done.toString()),
              _buildProgressDetail(context, 'Pending', applyProgress.pending.toString()),
              _buildProgressDetail(context, 'Idle', applyProgress.idle.toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDetail(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '• ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            const SizedBox(height: 16),
            _buildCardRow(
              context,
              label: 'Height',
              value: _fmtInt(_networkBestTipHeight ?? _currentBlockHeight),
            ),
            const SizedBox(height: 12),
            _buildCardRow(
              context,
              label: 'Hash',
              value: _bestTipHashDisplay(),
              monoValue: true,
            ),
            const SizedBox(height: 16),

            // Batches section with breakdown
            if (_bestTipBatchTransactions.isNotEmpty) ...[
              Text(
                'Batches (${_bestTipBatchTransactions.length} • ${_formatBatchesInline()})',
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
              _buildCardRow(
                context,
                label: 'Batches',
                value: 'No batches',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    bool monoValue = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontFamily: monoValue ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCardRowWithIcon(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onIconTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(icon, size: 20),
              tooltip: 'View details',
              onPressed: onIconTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
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

  // Unused helpers removed: _peersSummaryText, _peersBreakdownText, _buildPeersChips

  Widget _buildMinimalPeerStatus(BuildContext context) {
    int connected = 0;
    for (final p in _peers) {
      if (p.connectionStatus == PeerConnectionStatus.connected) {
        connected++;
      }
    }

    final theme = Theme.of(context);
    final total = _peers.length;

    return Text(
      '$connected of $total connected',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // Unused _extractPeerId removed

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
    // Check if we're synced based on:
    // 1. Current block height matches or exceeds network best tip
    // 2. Fetch and apply progress are complete (no pending blocks)
    final currentHeight = _currentBlockHeight;
    final bestTipHeight = _networkBestTipHeight;

    // If we don't have height info, check sync progress
    if (currentHeight == null || bestTipHeight == null) {
      // Consider synced if both fetch and apply have no pending work
      final fetchDone = _fetchProgress?.done ?? BigInt.zero;
      final fetchPending = _fetchProgress?.pending ?? BigInt.zero;
      final applyDone = _applyProgress?.done ?? BigInt.zero;
      final applyPending = _applyProgress?.pending ?? BigInt.zero;

      return fetchPending == BigInt.zero && applyPending == BigInt.zero &&
             (fetchDone > BigInt.zero || applyDone > BigInt.zero);
    }

    // Height-based check with sync progress validation
    final heightSynced = currentHeight >= bestTipHeight;
    final fetchPending = _fetchProgress?.pending ?? BigInt.zero;
    final applyPending = _applyProgress?.pending ?? BigInt.zero;

    // Fully synced if height matches AND no pending sync work
    return heightSynced && fetchPending == BigInt.zero && applyPending == BigInt.zero;
  }

  String _getSyncStatus() {
    if (_isSynced()) {
      return 'Synced & Healthy';
    }

    // Check if we're actively syncing
    final fetchPending = _fetchProgress?.pending ?? BigInt.zero;
    final applyPending = _applyProgress?.pending ?? BigInt.zero;

    if (fetchPending > BigInt.zero || applyPending > BigInt.zero) {
      return 'Syncing';
    }

    return 'Awaiting Sync';
  }

  String _formatEpochInline() {
    final slot = _bestTipGlobalSlot;
    final epoch = _bestTipEpoch;
    if (epoch == null || slot == null) return 'N/A';
    return 'Epoch $epoch • Slot $slot';
  }

  String _formatPeersInline() {
    int connected = 0;
    for (final p in _peers) {
      if (p.connectionStatus == PeerConnectionStatus.connected) {
        connected++;
      }
    }
    final total = _peers.length;
    return '$connected of $total';
  }

  String _formatSyncPercentage() {
    final currentHeight = _currentBlockHeight;
    final bestTipHeight = _networkBestTipHeight;

    if (currentHeight == null || bestTipHeight == null) {
      return 'N/A';
    }

    if (currentHeight >= bestTipHeight) {
      return '100% Complete';
    }

    if (bestTipHeight == 0) {
      return '0%';
    }

    final percentage = ((currentHeight / bestTipHeight) * 100).toStringAsFixed(1);
    return '$percentage%';
  }

  String _formatBatchesInline() {
    if (_bestTipBatchTransactions.isEmpty) {
      return _bestTipHash == null ? 'N/A' : '0 batches';
    }

    final batchCount = _bestTipBatchTransactions.length;
    final totalTxs = _bestTipBatchTransactions.fold<BigInt>(
      BigInt.zero,
      (sum, count) => sum + count,
    );

    return '$batchCount batches • $totalTxs transactions';
  }

  String _formatEpochSummary() {
    final slot = _fmtInt(_bestTipGlobalSlot);
    final epoch = _fmtInt(_bestTipEpoch);
    return 'Epoch: $epoch - Global Slot: $slot';
  }

  String _formatBestTipSummary() {
    final heightText =
        'Height: ${_fmtInt(_networkBestTipHeight ?? _currentBlockHeight)}';
    final hashText = 'Hash: ${_bestTipHashDisplay()}';
    final batchesText = _formatBatchSummary();
    return [heightText, hashText, batchesText].join('\n');
  }

  String _formatBatchSummary() {
    if (_bestTipBatchTransactions.isEmpty) {
      return _bestTipHash == null ? 'Batches: N/A' : 'Batches: 0';
    }
    final details = _bestTipBatchTransactions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final txCount = entry.value.toString();
      return 'Batch $idx: $txCount trx';
    }).join(', ');
    return 'Batches: ${_bestTipBatchTransactions.length} ($details)';
  }

  String _formatSyncStatusSummary() {
    final fetch = _formatProgress(_fetchProgress);
    final apply = _formatProgress(_applyProgress);
    return ['Fetch progress: $fetch', 'Apply progress: $apply'].join('\n');
  }

  String _formatProgress(_ProgressData? data) {
    if (data == null) return 'N/A';
    return 'done ${data.done}, pending ${data.pending}, idle ${data.idle}';
  }

  String _bestTipHashDisplay() {
    final hash = _bestTipHash;
    if (hash == null || hash.isEmpty) return 'N/A';
    return _shortenMid(hash, head: 10, tail: 10);
  }

  String _statusText() {
    final currentHeight = _currentBlockHeight;
    final bestTipHeight = _networkBestTipHeight;

    if (currentHeight == null && bestTipHeight == null) {
      return 'Awaiting status';
    }
    if (currentHeight != null && bestTipHeight != null) {
      return currentHeight >= bestTipHeight ? 'Synced' : 'Synching';
    }
    if (currentHeight != null) {
      return 'Synced';
    }
    return 'Synching';
  }


  int _secondsSinceCheck() {
    if (_lastChecked == null) return 0;
    final diff = DateTime.now().difference(_lastChecked!);
    return diff.inSeconds;
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _secondsTimer?.cancel();
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

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatusItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w400)),
      ],
    );
  }
}

// Removed unused _TabButton and _IconStatus widgets

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
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ScheduledSlotDetailsScreen(slotNumber: slotNumber),
            ),
          );
        },
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
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BlockDetailsScreen(blockNumber: blockNumber),
            ),
          );
        },
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
