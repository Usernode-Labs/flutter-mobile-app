import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';

/// Shows a bottom sheet with node status summary
void showNodeStatusSummaryModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
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
  final _appSleepService = AppSleepService.instance;
  Timer? _refreshTimer;
  double? _blocksPerSecond;
  int? _previousBlockHeight;
  DateTime? _previousHeightCheck;

  @override
  void initState() {
    super.initState();
    _appSleepService.addListener(_handleAppSleepChanged);
    // Auto-refresh every 3 seconds while modal is open
    if (_appSleepService.isSleeping) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appSleepService.isSleeping) return;
      if (mounted) {
        ref.read(nodeStatusProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _appSleepService.removeListener(_handleAppSleepChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _handleAppSleepChanged() {
    if (!mounted) return;
    if (_appSleepService.isSleeping) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appSleepService.isSleeping) return;
      if (mounted) {
        ref.read(nodeStatusProvider.notifier).refresh();
      }
    });
    ref.read(nodeStatusProvider.notifier).refresh();
  }

  TopStatusNodeVisual _resolveSyncVisual(
    BuildContext context,
    SyncStatus? syncStatus, {
    bool hasRealError = false,
    TopStatusNodeStatus nullStatus = TopStatusNodeStatus.connecting,
  }) {
    return TopStatusNodeVisual.resolve(
      context,
      topStatusNodeStatusFromSyncStatus(
        syncStatus,
        hasRealError: hasRealError,
        nullStatus: nullStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final statusAsync = ref.watch(nodeStatusProvider);
    final nodeStatus = statusAsync.valueOrNull;
    final syncStatus = nodeStatus?.syncStatus;

    return SheetLayout(
      title: 'Node Status',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync Status Card
            statusAsync.when(
              data: (status) {
                if (syncStatus == null) {
                  final visual = _resolveSyncVisual(context, null);

                  // Loading state
                  return _StatusCard(
                    icon: visual.icon,
                    iconColor: visual.foregroundColor,
                    iconBackgroundColor: visual.backgroundColor,
                    title: 'Sync Status',
                    child: Center(
                      child: Text(
                        'Loading...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                final currentHeight = syncStatus.localHeight ?? 0;
                final networkHeight = syncStatus.networkHeight ?? currentHeight;
                final syncPercentage = syncStatus.progress;

                // Calculate sync speed
                _updateSyncSpeed(currentHeight);

                final visual = _resolveSyncVisual(context, syncStatus);
                final accentColor = visual.foregroundColor;

                return _StatusCard(
                  icon: visual.icon,
                  iconColor: accentColor,
                  iconBackgroundColor: visual.backgroundColor,
                  title: 'Sync Status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            visual.label,
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
                      SizedBox(height: spacing.space8),
                      ClipRRect(
                        borderRadius: radii.borderRadiusXSmall,
                        child: LinearProgressIndicator(
                          value: syncPercentage,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accentColor),
                          minHeight: 6,
                        ),
                      ),
                      SizedBox(height: spacing.space8),
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
                        SizedBox(height: spacing.space4),
                        Row(
                          children: [
                            Icon(Symbols.speed_sharp,
                                size: sizing.iconXSmall,
                                color: colorScheme.onSurfaceVariant),
                            SizedBox(width: spacing.space4),
                            Text(
                              '${_blocksPerSecond!.toStringAsFixed(1)} blocks/sec',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(width: spacing.space12),
                            Icon(Symbols.schedule_sharp,
                                size: sizing.iconXSmall,
                                color: colorScheme.onSurfaceVariant),
                            SizedBox(width: spacing.space4),
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
                if (nodeStatus != null && syncStatus != null) {
                  final currentHeight = nodeStatus.localBestHeight ?? 0;
                  final networkHeight =
                      nodeStatus.networkBestHeight ?? currentHeight;
                  final syncPercentage = syncStatus.progress;

                  final visual = _resolveSyncVisual(context, syncStatus);
                  final accentColor = visual.foregroundColor;

                  return _StatusCard(
                    icon: visual.icon,
                    iconColor: accentColor,
                    iconBackgroundColor: visual.backgroundColor,
                    title: 'Sync Status',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              visual.label,
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
                        SizedBox(height: spacing.space8),
                        ClipRRect(
                          borderRadius: radii.borderRadiusXSmall,
                          child: LinearProgressIndicator(
                            value: syncPercentage,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accentColor),
                            minHeight: 6,
                          ),
                        ),
                        SizedBox(height: spacing.space8),
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
                          SizedBox(height: spacing.space4),
                          Row(
                            children: [
                              Icon(Symbols.speed_sharp,
                                  size: sizing.iconXSmall,
                                  color: colorScheme.onSurfaceVariant),
                              SizedBox(width: spacing.space4),
                              Text(
                                '${_blocksPerSecond!.toStringAsFixed(1)} blocks/sec',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(width: spacing.space12),
                              Icon(Symbols.schedule_sharp,
                                  size: sizing.iconXSmall,
                                  color: colorScheme.onSurfaceVariant),
                              SizedBox(width: spacing.space4),
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
                final visual = _resolveSyncVisual(context, null);
                final accentColor = visual.foregroundColor;
                return _StatusCard(
                  icon: visual.icon,
                  iconColor: accentColor,
                  iconBackgroundColor: visual.backgroundColor,
                  title: 'Sync Status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            visual.label,
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
                      SizedBox(height: spacing.space8),
                      ClipRRect(
                        borderRadius: radii.borderRadiusXSmall,
                        child: LinearProgressIndicator(
                          value: 0.0,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accentColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              },
              error: (_, __) {
                final visual = _resolveSyncVisual(
                  context,
                  syncStatus,
                  hasRealError: true,
                );

                return _StatusCard(
                  icon: visual.icon,
                  iconColor: visual.foregroundColor,
                  iconBackgroundColor: visual.backgroundColor,
                  title: 'Sync Status',
                  child: Text(
                    'Error loading status',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: visual.foregroundColor,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: spacing.space12),

            // Peers and Epoch Row
            Row(
              children: [
                Expanded(
                  child: statusAsync.when(
                    data: (status) {
                      final connectedPeers = status?.connectedPeers ?? 0;
                      final totalPeers = status?.totalPeers ?? 0;
                      final peerHealthy =
                          connectedPeers > 0 && connectedPeers == totalPeers;

                      return _StatusCard(
                        icon: Symbols.people_sharp,
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
                      if (nodeStatus != null) {
                        final connectedPeers = nodeStatus.connectedPeers;
                        final totalPeers = nodeStatus.totalPeers;
                        final peerHealthy =
                            connectedPeers > 0 && connectedPeers == totalPeers;

                        return _StatusCard(
                          icon: Symbols.people_sharp,
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
                        icon: Symbols.people_sharp,
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
                      icon: Symbols.people_sharp,
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
                SizedBox(width: spacing.space12),
                Expanded(
                  child: statusAsync.when(
                    data: (status) {
                      final epoch = status?.epoch;
                      final globalSlot = status?.globalSlot;

                      return _StatusCard(
                        icon: Symbols.access_time_sharp,
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
                      if (nodeStatus != null) {
                        final epoch = nodeStatus.epoch;
                        final globalSlot = nodeStatus.globalSlot;

                        return _StatusCard(
                          icon: Symbols.access_time_sharp,
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
                        icon: Symbols.access_time_sharp,
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
                      icon: Symbols.access_time_sharp,
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

            // The full node-status detail screen moved into SV (drawer node
            // sheet); this native modal is now summary-only.
            SizedBox(height: spacing.space8),
          ],
        ),
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
  final Color? iconBackgroundColor;
  final String title;
  final Widget child;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    this.iconBackgroundColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final badgeSize = sizing.iconSmall + spacing.space4;
    final iconWidget = iconBackgroundColor == null
        ? Icon(icon, size: sizing.iconXSmall, color: iconColor)
        : Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: sizing.iconXSmall, color: iconColor),
          );

    return Container(
      padding: EdgeInsets.all(spacing.space12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: radii.borderRadiusMedium,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconWidget,
              SizedBox(width: spacing.space4),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.space8),
          child,
        ],
      ),
    );
  }
}
