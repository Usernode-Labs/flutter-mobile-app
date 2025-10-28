import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_status_provider.dart';

/// Shows a bottom sheet with node status summary
void showNodeStatusSummaryModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const NodeStatusSummaryModal(),
  );
}

/// Modal that displays a quick summary of node status
class NodeStatusSummaryModal extends ConsumerStatefulWidget {
  const NodeStatusSummaryModal({super.key});

  @override
  ConsumerState<NodeStatusSummaryModal> createState() =>
      _NodeStatusSummaryModalState();
}

class _NodeStatusSummaryModalState
    extends ConsumerState<NodeStatusSummaryModal> {
  Timer? _refreshTimer;
  double? _blocksPerSecond;
  int? _previousBlockHeight;
  DateTime? _previousHeightCheck;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 3 seconds while modal is open
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        ref.read(nodeRawStatusProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncStatus = ref.watch(syncStatusProvider);
    final nodeStatusAsync = ref.watch(nodeStatusProvider);
    final nodeRawAsync = ref.watch(nodeRawStatusProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Node Status',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sync Status Card
          nodeStatusAsync.when(
            data: (nodeStatus) {
              final currentHeight = syncStatus.localHeight ?? 0;
              final networkHeight = syncStatus.networkHeight ?? currentHeight;
              final syncPercentage = syncStatus.progress;

              // Calculate sync speed
              _updateSyncSpeed(currentHeight);

              // Determine icon and color based on state
              final IconData icon;
              final Color accentColor;
              final String statusLabel;

              if (syncStatus.isConnecting) {
                icon = Icons.hourglass_empty;
                accentColor = colorScheme.outline;
                statusLabel = 'Connecting';
              } else if (syncStatus.isSynced) {
                icon = Icons.check_circle;
                accentColor = colorScheme.tertiary;
                statusLabel = 'Synced';
              } else if (syncStatus.isSyncing) {
                icon = Icons.sync;
                accentColor = colorScheme.primary;
                statusLabel = 'Syncing';
              } else {
                icon = Icons.error;
                accentColor = colorScheme.error;
                statusLabel = 'Error';
              }

              return _StatusCard(
                icon: icon,
                iconColor: accentColor,
                title: 'Sync Status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          statusLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          '${(syncPercentage * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: syncPercentage,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Show appropriate message based on state
                    if (syncStatus.isConnecting) ...[
                      Text(
                        'Waiting for peer connections...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${syncStatus.connectedPeers} peers connected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Block $currentHeight / $networkHeight',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (syncStatus.blocksRemaining != null) ...[
                        Text(
                          '${syncStatus.blocksRemaining} blocks remaining',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                    if (syncStatus.isSyncing &&
                        _blocksPerSecond != null &&
                        _blocksPerSecond! > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.speed,
                              size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${_blocksPerSecond!.toStringAsFixed(1)} blocks/sec',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule,
                              size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: ${_calculateETA(currentHeight, networkHeight, _blocksPerSecond!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () {
              // Check if we have previous data to avoid blinking
              final previousData = nodeStatusAsync.valueOrNull;
              if (previousData != null) {
                final currentHeight = previousData.localBestHeight ?? 0;
                final networkHeight = previousData.networkBestHeight ?? currentHeight;
                final syncPercentage =
                    networkHeight > 0 ? (currentHeight / networkHeight) : 1.0;

                final accentColor = syncStatus.isSynced
                    ? colorScheme.tertiary
                    : colorScheme.primary;

                return _StatusCard(
                  icon: syncStatus.isSynced ? Icons.check_circle : Icons.sync,
                  iconColor: accentColor,
                  title: 'Sync Status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            syncStatus.isSynced ? 'Synced' : 'Syncing',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            '${(syncPercentage * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: syncPercentage,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!syncStatus.isConnecting)
                        Text(
                          'Block $currentHeight / $networkHeight',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (!syncStatus.isSynced &&
                          _blocksPerSecond != null &&
                          _blocksPerSecond! > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.speed,
                                size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${_blocksPerSecond!.toStringAsFixed(1)} blocks/sec',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.schedule,
                                size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'ETA: ${_calculateETA(currentHeight, networkHeight, _blocksPerSecond!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }
              // Show default values when no previous data (instead of placeholder)
              final accentColor = colorScheme.outline;
              return _StatusCard(
                icon: Icons.hourglass_empty,
                iconColor: accentColor,
                title: 'Sync Status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connecting',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          '0.0%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            },
            error: (_, __) => _StatusCard(
              icon: Icons.error,
              iconColor: colorScheme.error,
              title: 'Sync Status',
              child: Text(
                'Error loading status',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Peers and Epoch Row
          Row(
            children: [
              Expanded(
                child: nodeRawAsync.when(
                  data: (raw) {
                    final connectedPeers = raw?.connectedPeers ?? 0;
                    final totalPeers = raw?.totalPeers ?? 0;
                    final peerHealthy =
                        connectedPeers > 0 && connectedPeers == totalPeers;

                    return _StatusCard(
                      icon: Icons.people,
                      iconColor: peerHealthy
                          ? colorScheme.tertiary
                          : colorScheme.error,
                      title: 'Peers',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$connectedPeers/$totalPeers',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            peerHealthy ? 'All connected' : 'Some offline',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () {
                    // Check if we have previous data to avoid blinking
                    final previousData = nodeRawAsync.valueOrNull;
                    if (previousData != null) {
                      final connectedPeers = previousData.connectedPeers;
                      final totalPeers = previousData.totalPeers;
                      final peerHealthy =
                          connectedPeers > 0 && connectedPeers == totalPeers;

                      return _StatusCard(
                        icon: Icons.people,
                        iconColor: peerHealthy
                            ? colorScheme.tertiary
                            : colorScheme.error,
                        title: 'Peers',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$connectedPeers/$totalPeers',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              peerHealthy ? 'All connected' : 'Some offline',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // Show default values when no previous data (instead of placeholder)
                    return _StatusCard(
                      icon: Icons.people,
                      iconColor: colorScheme.error,
                      title: 'Peers',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0/0',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'No peers',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  error: (_, __) => _StatusCard(
                    icon: Icons.people,
                    iconColor: colorScheme.error,
                    title: 'Peers',
                    child: Text(
                      'Error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: nodeStatusAsync.when(
                  data: (nodeStatus) {
                    final epoch = nodeStatus?.epoch;
                    final globalSlot = nodeStatus?.globalSlot;

                    return _StatusCard(
                      icon: Icons.access_time,
                      iconColor: colorScheme.primary,
                      title: 'Epoch',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            epoch != null ? '$epoch' : 'N/A',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            globalSlot != null ? 'Slot $globalSlot' : 'N/A',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () {
                    // Check if we have previous data to avoid blinking
                    final previousData = nodeStatusAsync.valueOrNull;
                    if (previousData != null) {
                      final epoch = previousData.epoch;
                      final globalSlot = previousData.globalSlot;

                      return _StatusCard(
                        icon: Icons.access_time,
                        iconColor: colorScheme.primary,
                        title: 'Epoch',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              epoch != null ? '$epoch' : 'N/A',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              globalSlot != null ? 'Slot $globalSlot' : 'N/A',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // Show default values when no previous data (instead of placeholder)
                    return _StatusCard(
                      icon: Icons.access_time,
                      iconColor: colorScheme.primary,
                      title: 'Epoch',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Slot 0',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  error: (_, __) => _StatusCard(
                    icon: Icons.access_time,
                    iconColor: colorScheme.error,
                    title: 'Epoch',
                    child: Text(
                      'Error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // View Details Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/main/node');
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Details'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _updateSyncSpeed(int? currentHeight) {
    if (currentHeight == null) return;

    final now = DateTime.now();
    if (_previousBlockHeight != null &&
        _previousHeightCheck != null &&
        currentHeight > _previousBlockHeight!) {
      final timeDiff = now.difference(_previousHeightCheck!).inSeconds;
      if (timeDiff > 0) {
        final blockDiff = currentHeight - _previousBlockHeight!;
        setState(() {
          _blocksPerSecond = blockDiff / timeDiff;
        });
      }
    }
    _previousBlockHeight = currentHeight;
    _previousHeightCheck = now;
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
}

/// Reusable card widget for status items
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
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
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
