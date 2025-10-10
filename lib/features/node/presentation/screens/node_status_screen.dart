import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/slot_heatmap.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'node_peers_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/core/result.dart';
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
  // Provider-driven; local state only for UI meta like last-checked timestamp

  Timer? _autoTimer;
  late final TabController _tabController;
  DateTime? _lastChecked;

  // Soft tinted surface helper for modern light backgrounds
  Color _tint(ColorScheme scheme, Color accent, [double opacity = 0.06]) {
    return Color.alphaBlend(accent.withValues(alpha: opacity), scheme.surface);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer provider modifications until after the first frame to avoid
    // "modify provider while building" errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
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
      Log.d('NODE', 'Refreshing node providers');
      // Invalidate to trigger provider rebuilds (respects test overrides)
      ref.invalidate(nodeStatusProvider);
      ref.invalidate(nodeMempoolProvider);
      ref.invalidate(nodeBlockchainProvider);
      ref.invalidate(nodeEpochRewardsProvider);
      ref.invalidate(nodeRawStatusProvider);
      if (!mounted) return;
      setState(() {
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
      appBar: AppAppBar(
        title: 'Node Status',
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            tooltip: 'Cycle Theme',
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
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

              // Activity Section with Tabs
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Produced Blocks')),
                  ButtonSegment(value: 1, label: Text('Scheduled Slots')),
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
                // Produced Blocks Tab
                _buildProducedBlocksTab(context)
              else
                // Scheduled Slots Tab
                _buildScheduledSlotsTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard(BuildContext context, NodeStatus? statusFromProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = ref.watch(syncStatusProvider);
    final isSynced = sync.isSynced;
    final statusText = sync.label;

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
    final currentHeight = statusFromProvider?.localBestHeight ??
        ref.watch(nodeRawStatusProvider).value?.localBestHeight ??
        0;
    final networkHeight = statusFromProvider?.networkBestHeight ??
        ref.watch(nodeRawStatusProvider).value?.networkBestHeight ??
        currentHeight;
    final syncPercentage = networkHeight > 0 ? (currentHeight / networkHeight) : sync.progress;

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
                    icon: Icon(Icons.info_outline,
                        color: statusTextColor, size: 16),
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
                  onTap: () {
                    final raw = ref.read(nodeRawStatusProvider).value;
                    final peers = raw?.peers ?? const <RpcPeerInfo>[];
                    if (peers.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NodePeersScreen(peers: peers),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                // Epoch/Slot info (not clickable)
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: colorScheme.onSurfaceVariant),
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
            (fetchProgress.done.toInt() / total.toInt()) * 100;
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
            (applyProgress.done.toInt() / total.toInt()) * 100;
      } else {
        // If total is zero (no work), consider it 100% complete
        applyPercentage = 100.0;
      }
    } else {
      // If no progress data, consider it 100% complete
      applyPercentage = 100.0;
    }

    final bg = _tint(colorScheme, colorScheme.primary);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
    final raw = ref.watch(nodeRawStatusProvider).value;

    final bg = _tint(colorScheme, colorScheme.secondary);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
            Builder(builder: (_) {
              final height = raw?.networkBestHeight ?? raw?.localBestHeight;
              final hash = raw?.bestTipHash;
              final displayHash = () {
                if (hash == null || hash.isEmpty) return 'N/A';
                final h = hash;
                final head = h.length >= 10 ? h.substring(0, 10) : h;
                final tail = h.length >= 10 ? h.substring(h.length - 10) : '';
                return '$head…$tail';
              }();
              return Text(
                'Height: ${_fmtInt(height)} ($displayHash)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Batches section with breakdown
            if (raw?.bestTipBatchTransactions.isNotEmpty == true) ...[
              Text(
                'Batches (${(raw?.bestTipBatchTransactions.length ?? 0)} total)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...(raw?.bestTipBatchTransactions ?? const <BigInt>[])
                  .asMap()
                  .entries
                  .map((entry) {
                final batchIndex = entry.key + 1;
                final txCount = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final useResult = ref.watch(useResultProvidersProvider);
    final mempoolAsync = useResult
        ? ref.watch(nodeMempoolResultProvider)
        : ref.watch(nodeMempoolProvider);

    final bg = _tint(colorScheme, colorScheme.primary, 0.04);
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions,
                    size: 20, color: colorScheme.primary),
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
            useResult
                ? (mempoolAsync as AsyncValue<Result<RpcListMempoolResp?>>).when(
                    loading: () => Text(
                      'Loading...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    error: (e, _) => Text(
                      'Failed to load mempool',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    data: (res) {
                      if (res.isErr) {
                        return Text(
                          'Failed to load mempool',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        );
                      }
                      final mempool = res.ok;
                      if (mempool == null) {
                        return Text(
                          'No mempool data',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      }
                      return _buildMempoolContent(context, theme, colorScheme, mempool);
                    },
                  )
                : (mempoolAsync as AsyncValue<RpcListMempoolResp?>).when(
                  loading: () => Text(
                    'Loading...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  error: (e, _) => Text(
                    'Failed to load mempool',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                  data: (mempool) => mempool == null
                      ? Text(
                          'No mempool data',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : _buildMempoolContent(context, theme, colorScheme, mempool),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildMempoolContent(BuildContext context, ThemeData theme, ColorScheme colorScheme, RpcListMempoolResp mempool) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          ...mempool.entries.take(5).map((tx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {},
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
                          Icon(Icons.receipt_long, size: 16, color: colorScheme.primary),
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

  // Removed unused _shortenMid helper

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

  // Removed legacy sync helpers; use syncStatusProvider instead

  String _formatEpochInline() {
    final raw = ref.read(nodeRawStatusProvider).value;
    final slot = raw?.globalSlot;
    final epoch = raw?.epoch;
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

  // Removed _bestTipHashDisplay; best tip hash computed directly from provider

  Widget _buildScheduledSlotsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useResult = ref.watch(useResultProvidersProvider);
    final rewardsAsync = useResult
        ? ref.watch(nodeEpochRewardsResultProvider)
        : ref.watch(nodeEpochRewardsProvider);
    final blockchainAsync = useResult
        ? ref.watch(nodeBlockchainResultProvider)
        : ref.watch(nodeBlockchainProvider);

    if (useResult) {
      final rewardsRes = rewardsAsync as AsyncValue<Result<RpcEpochRewardsResp?>>;
      final chainRes = blockchainAsync as AsyncValue<Result<RpcListBlockchainResp?>>;

      final isLoading = rewardsRes.isLoading || chainRes.isLoading;
      if (isLoading) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Loading epoch data...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      if (rewardsRes.hasError || chainRes.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Epoch data unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
        );
      }

      final rewardsResult = rewardsRes.value;
      final chainResult = chainRes.value;
      if (rewardsResult == null || chainResult == null ||
          rewardsResult.isErr || chainResult.isErr) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Epoch data unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
        );
      }

      final rewards = rewardsResult.ok;
      final blockchain = chainResult.ok;
      if (rewards == null || blockchain == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Epoch data unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      // Proceed with rendering using rewards and blockchain below
      // (fall through to common rendering by reusing variables)

      // Display blocks from the blockchain
      final blocks = blockchain.items.take(10).toList();
      final bestTipSlot = ref.watch(nodeRawStatusProvider).value?.globalSlot;
      final rewardPerBlock = rewards.rewardPerBlock;

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

    // Default (non-result) behavior
    final rewards = (rewardsAsync as AsyncValue<RpcEpochRewardsResp?>).value;
    final blockchain = (blockchainAsync as AsyncValue<RpcListBlockchainResp?>).value;

    if (rewards == null || blockchain == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            (rewardsAsync.isLoading || blockchainAsync.isLoading)
                ? 'Loading epoch data...'
                : 'Epoch data unavailable',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: (rewardsAsync.isLoading || blockchainAsync.isLoading)
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.error,
            ),
          ),
        ),
      );
    }

    // Get produced block slots from blockchain data
    final producedSlots = blockchain.items
        .where((block) => block.epoch == rewards.epoch)
        .map((block) => block.globalSlot)
        .toSet();

    // Get won slots list
    final wonSlots = rewards.wonSlots ?? [];

    // Producer pubkey
    // final producerPubkey = rewards.producerPubkey; // reserved for future display

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
            ],
          ),
        ),

        // Won Slots Heatmap
        if (wonSlots.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Won Slots Timeline',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Build heatmap data
          SlotHeatmap(
            slots: wonSlots.map((slot) {
              // Determine if this slot has been produced
              final isProduced = producedSlots.contains(slot.globalSlot);

              // Determine status
              SlotHeatmapStatus status;
              if (isProduced) {
                status = SlotHeatmapStatus.produced;
              } else {
                // Check if slot time has passed
                final now = DateTime.now().toUtc();
                final slotTime = DateTime.fromMillisecondsSinceEpoch(
                  slot.expectedTimeMs.toInt(),
                  isUtc: true,
                );
                if (now.isAfter(slotTime)) {
                  status = SlotHeatmapStatus.missed;
                } else {
                  status = SlotHeatmapStatus.pending;
                }
              }

              return SlotHeatmapData(
                slot: slot,
                status: status,
              );
            }).toList(),
            slotsPerRow: 10,
            cellSize: 32,
            cellSpacing: 6,
          ),
        ] else ...[
          const SizedBox(height: 24),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No won slots data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
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
    final useResult = ref.watch(useResultProvidersProvider);

    if (useResult) {
      final rewardsRes = ref.watch(nodeEpochRewardsResultProvider);
      final chainRes = ref.watch(nodeBlockchainResultProvider);
      final bestTipSlot = ref.watch(nodeRawStatusProvider).value?.globalSlot;

      if (rewardsRes.isLoading || chainRes.isLoading) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Loading produced blocks...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      if (rewardsRes.hasError || chainRes.hasError) {
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

      final rewardsResult = rewardsRes.value;
      final chainResult = chainRes.value;
      if (rewardsResult == null || chainResult == null ||
          rewardsResult.isErr || chainResult.isErr) {
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

      final rewards = rewardsResult.ok;
      final blockchain = chainResult.ok;
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

      final rewardPerBlock = rewards?.rewardPerBlock ?? BigInt.zero;
      final blocks = blockchain.items.take(10).toList();
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

    // Default non-result behavior
    final blockchainAsync = ref.watch(nodeBlockchainProvider);
    final rewardsAsync = ref.watch(nodeEpochRewardsProvider);
    final bestTipSlot = ref.watch(nodeRawStatusProvider).value?.globalSlot;

    if (blockchainAsync.isLoading || rewardsAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Loading produced blocks...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (blockchainAsync.hasError || rewardsAsync.hasError) {
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

    final blockchain = blockchainAsync.value;
    final rewards = rewardsAsync.value;
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

    final rewardPerBlock = rewards?.rewardPerBlock ?? BigInt.zero;
    final blocks = blockchain.items.take(10).toList();
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

// Progress data class removed; use nodeRawStatusProvider.

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
