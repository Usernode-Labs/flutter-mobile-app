import 'dart:async';
import 'package:flutter/material.dart';
import '../services/slot_monitor_service.dart';
import '../services/epoch_slot_scheduler_service.dart';

/// Widget that displays current slot monitoring status
///
/// Shows:
/// - Current monitoring state (active/inactive)
/// - Next upcoming slot
/// - Real-time monitoring events
/// - Visual indicators for block production
class SlotMonitoringStatusWidget extends StatefulWidget {
  const SlotMonitoringStatusWidget({super.key});

  @override
  State<SlotMonitoringStatusWidget> createState() =>
      _SlotMonitoringStatusWidgetState();
}

class _SlotMonitoringStatusWidgetState
    extends State<SlotMonitoringStatusWidget> {
  StreamSubscription<SlotMonitoringEvent>? _monitoringSubscription;
  SlotMonitoringEvent? _latestEvent;
  ScheduledSlot? _nextSlot;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _setupMonitoringListener();
    _updateNextSlot();

    // Update next slot every 10 seconds
    _updateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateNextSlot(),
    );
  }

  @override
  void dispose() {
    _monitoringSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _setupMonitoringListener() {
    _monitoringSubscription =
        SlotMonitorService.instance.monitoringEvents.listen((event) {
      if (mounted) {
        setState(() {
          _latestEvent = event;
        });
      }
    });
  }

  void _updateNextSlot() {
    final nextSlot = EpochSlotSchedulerService.instance.getNextSlot();
    if (mounted && nextSlot != _nextSlot) {
      setState(() {
        _nextSlot = nextSlot;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMonitoring = SlotMonitorService.instance.isMonitoring;

    return Card(
      elevation: isMonitoring ? 4 : 2,
      color: isMonitoring
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildStatusIndicator(isMonitoring, colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMonitoring
                            ? 'Monitoring Active'
                            : 'Monitoring Inactive',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isMonitoring
                              ? colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      if (isMonitoring && _latestEvent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getEventDescription(_latestEvent!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isMonitoring
                                ? colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8)
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Next slot info
            if (_nextSlot != null && !isMonitoring) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Next Slot',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slot ${_nextSlot!.slotNumber}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    _formatTimeUntil(_nextSlot!.slotTime),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],

            // Current monitoring slot
            if (isMonitoring &&
                SlotMonitorService.instance.currentSlot != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.play_circle,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Slot',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Slot ${SlotMonitorService.instance.currentSlot!.slotNumber}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              if (SlotMonitorService.instance.monitoringDuration != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Monitoring for ${_formatDuration(SlotMonitorService.instance.monitoringDuration!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],

            // Event timeline (last 3 events)
            if (isMonitoring && _latestEvent != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Recent Events',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              _buildEventItem(_latestEvent!, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isActive, ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isActive ? colorScheme.primary : colorScheme.surfaceContainerHigh,
      ),
      child: isActive
          ? Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.radar,
                  color: colorScheme.onPrimary,
                  size: 24,
                ),
                // Pulsing animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    // Create repeating animation manually
                    final animatedValue = (value * 2) % 1.0;
                    return Opacity(
                      opacity: 1 - animatedValue,
                      child: Container(
                        width: 48 * (1 + animatedValue * 0.5),
                        height: 48 * (1 + animatedValue * 0.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    // Trigger rebuild to restart animation
                    if (mounted) setState(() {});
                  },
                ),
              ],
            )
          : Icon(
              Icons.pause_circle_outline,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 24,
            ),
    );
  }

  Widget _buildEventItem(SlotMonitoringEvent event, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            _getEventIcon(event.type),
            size: 16,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getEventDescription(event),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(MonitoringEventType type) {
    switch (type) {
      case MonitoringEventType.started:
        return Icons.play_arrow;
      case MonitoringEventType.stopped:
        return Icons.stop;
      case MonitoringEventType.stateChanged:
        return Icons.sync;
      case MonitoringEventType.tipAdvanced:
        return Icons.trending_up;
      case MonitoringEventType.slotProduced:
        return Icons.check_circle;
      case MonitoringEventType.timeout:
        return Icons.timer_off;
      case MonitoringEventType.error:
        return Icons.error;
    }
  }

  String _getEventDescription(SlotMonitoringEvent event) {
    switch (event.type) {
      case MonitoringEventType.started:
        return 'Monitoring started for slot ${event.slotNumber}';
      case MonitoringEventType.stopped:
        return 'Monitoring stopped';
      case MonitoringEventType.stateChanged:
        return 'Node state: ${event.nodeState ?? "unknown"}';
      case MonitoringEventType.tipAdvanced:
        return 'Best tip advanced to slot ${event.bestTipSlot}';
      case MonitoringEventType.slotProduced:
        return 'Block produced successfully! Height: ${event.blockHeight}';
      case MonitoringEventType.timeout:
        return 'Monitoring timed out for slot ${event.slotNumber}';
      case MonitoringEventType.error:
        return 'Error: ${event.error ?? "Unknown error"}';
    }
  }

  String _formatTimeUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      return 'Past';
    } else if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return 'in ${hours}h ${minutes}m';
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      return 'in ${days}d ${hours}h';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}
