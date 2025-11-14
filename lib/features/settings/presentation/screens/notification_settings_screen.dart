import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/notification_config.dart';
import 'package:crypto_mobile_app/core/data/notification_state_repository.dart';
import 'package:crypto_mobile_app/core/services/local_notification_service.dart';
import 'package:crypto_mobile_app/core/services/slot_notification_manager.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

/// Screen for managing notification settings
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final _stateRepo = NotificationStateRepository.instance;
  final _notificationService = LocalNotificationService.instance;
  final _slotManager = SlotNotificationManager.instance;

  bool _notificationsEnabled = true;
  bool _upcomingEnabled = true;
  bool _producedEnabled = true;
  bool _missedEnabled = true;
  bool _smartBatchingEnabled = true;
  int _advanceMinutes = 10;
  bool _loading = true;
  bool _debugExpanded = false;
  List<ScheduledNotification> _scheduledNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      setState(() {
        _notificationsEnabled = _stateRepo.notificationsEnabled;
        _upcomingEnabled = _stateRepo.upcomingNotificationsEnabled;
        _producedEnabled = _stateRepo.producedNotificationsEnabled;
        _missedEnabled = _stateRepo.missedNotificationsEnabled;
        _smartBatchingEnabled = _stateRepo.smartBatchingEnabled;
        _advanceMinutes = _stateRepo.advanceWarningMinutes;
      });
      _loadScheduledNotifications();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _loadScheduledNotifications() {
    final notifications = _stateRepo.getScheduledNotifications();
    // Sort by scheduled time (soonest first)
    notifications.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    setState(() {
      _scheduledNotifications = notifications;
    });
  }

  Future<void> _updateNotificationsEnabled(bool value) async {
    if (value) {
      // Request permissions when enabling
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permissions denied'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    await _stateRepo.setNotificationsEnabled(value);
    setState(() => _notificationsEnabled = value);

    if (value) {
      await _rescheduleNotifications();
    } else {
      await _slotManager.cancelAllScheduledNotifications();
    }
  }

  Future<void> _updateUpcomingEnabled(bool value) async {
    await _stateRepo.setUpcomingNotificationsEnabled(value);
    setState(() => _upcomingEnabled = value);
    if (_notificationsEnabled) {
      await _rescheduleNotifications();
    }
  }

  Future<void> _updateProducedEnabled(bool value) async {
    await _stateRepo.setProducedNotificationsEnabled(value);
    setState(() => _producedEnabled = value);
  }

  Future<void> _updateMissedEnabled(bool value) async {
    await _stateRepo.setMissedNotificationsEnabled(value);
    setState(() => _missedEnabled = value);
  }

  Future<void> _updateSmartBatchingEnabled(bool value) async {
    await _stateRepo.setSmartBatchingEnabled(value);
    setState(() => _smartBatchingEnabled = value);
    if (_notificationsEnabled) {
      await _rescheduleNotifications();
    }
  }

  Future<void> _updateAdvanceMinutes(int value) async {
    await _stateRepo.setAdvanceWarningMinutes(value);
    setState(() => _advanceMinutes = value);
    if (_notificationsEnabled) {
      await _rescheduleNotifications();
    }
  }

  Future<void> _rescheduleNotifications() async {
    // Get current epoch rewards to re-schedule
    final rewardsAsync = ref.read(nodeEpochRewardsProvider);
    final rewards = rewardsAsync.value;

    if (rewards?.wonSlots != null) {
      final blockchainAsync = ref.read(nodeBlockchainProvider);
      final blockchain = blockchainAsync.value;

      final producedSlots = <int>{};
      if (blockchain?.items != null) {
        for (final block in blockchain!.items) {
          producedSlots.add(block.globalSlot);
        }
      }

      await _slotManager.rescheduleNotifications(
        wonSlots: rewards!.wonSlots!,
        producedSlots: producedSlots,
        epoch: rewards.epoch,
      );

      // Refresh debug view
      _loadScheduledNotifications();
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showNotification(
      id: 99999,
      title: 'Test Notification',
      body: 'This is a test notification from your node app!',
      isSlotNotification: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification Settings'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // Main Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.notifications, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Enable Notifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: _updateNotificationsEnabled,
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive notifications for won slots'),
            secondary: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: colorScheme.primary,
            ),
          ),

          if (_notificationsEnabled) ...[
            const Divider(),

            // Notification Types
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.category, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Notification Types',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: _upcomingEnabled,
              onChanged: _updateUpcomingEnabled,
              title: const Text('Upcoming Slots'),
              subtitle: Text(
                'Notify $_advanceMinutes minutes before each slot',
              ),
              secondary: const Icon(Icons.schedule),
            ),
            SwitchListTile(
              value: _producedEnabled,
              onChanged: _updateProducedEnabled,
              title: const Text('Block Produced'),
              subtitle:
                  const Text('Notify when blocks are successfully produced'),
              secondary: const Icon(Icons.check_circle),
            ),
            SwitchListTile(
              value: _missedEnabled,
              onChanged: _updateMissedEnabled,
              title: const Text('Missed Slots'),
              subtitle: const Text('Notify when slots are missed'),
              secondary: const Icon(Icons.error_outline),
            ),

            const Divider(),

            // Advance Warning Time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Advance Warning',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notify me',
                            style: theme.textTheme.bodyLarge,
                          ),
                          Text(
                            '$_advanceMinutes minutes before',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: NotificationConfig.advanceWarningOptions
                            .map((minutes) => ChoiceChip(
                                  label: Text('$minutes min'),
                                  selected: _advanceMinutes == minutes,
                                  onSelected: (selected) {
                                    if (selected) {
                                      _updateAdvanceMinutes(minutes);
                                    }
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(),

            // Smart Batching
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.smart_toy, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Smart Features',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: _smartBatchingEnabled,
              onChanged: _updateSmartBatchingEnabled,
              title: const Text('Smart Batching'),
              subtitle: const Text(
                'Group nearby slots to avoid overwhelming notifications',
              ),
              secondary: const Icon(Icons.auto_awesome),
            ),

            const Divider(),

            // Statistics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.analytics, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Statistics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatRow(
                        'Scheduled notifications',
                        '${_stateRepo.scheduledNotificationCount}',
                        theme,
                      ),
                      const Divider(),
                      _buildStatRow(
                        'Max per hour',
                        '${NotificationConfig.maxNotificationsPerHour}',
                        theme,
                      ),
                      const Divider(),
                      _buildStatRow(
                        'Grouping window',
                        '${NotificationConfig.groupingWindow.inMinutes} min',
                        theme,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debug Section
            _buildDebugSection(theme, colorScheme),

            const SizedBox(height: 16),

            // Test Notification Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _testNotification,
                icon: const Icon(Icons.send),
                label: const Text('Send Test Notification'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationDebugItem(
    ScheduledNotification notification,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final now = DateTime.now();
    final dateFormatter = DateFormat('MMM d, h:mm a');
    final notifyTimeStr = dateFormatter.format(notification.scheduledTime);
    final slotTimeStr = dateFormatter.format(notification.slotTime);

    // Get relative time for notification
    final relativeTime = notification.scheduledTime.isAfter(now)
        ? timeago.format(notification.scheduledTime, allowFromNow: true)
        : 'Past';

    // Color and icon based on type
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (notification.type) {
      case SlotNotificationType.upcoming:
        typeColor = Colors.blue;
        typeIcon = Icons.schedule;
        typeLabel = 'Upcoming';
        break;
      case SlotNotificationType.grouped:
        typeColor = Colors.purple;
        typeIcon = Icons.group_work;
        typeLabel = 'Grouped';
        break;
      case SlotNotificationType.produced:
        typeColor = Colors.green;
        typeIcon = Icons.check_circle;
        typeLabel = 'Produced';
        break;
      case SlotNotificationType.missed:
        typeColor = Colors.red;
        typeIcon = Icons.error;
        typeLabel = 'Missed';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and slot
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Slot #${notification.globalSlot}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Notification time
            Row(
              children: [
                Icon(Icons.notifications,
                    size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notify: $notifyTimeStr',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  relativeTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Slot time
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(
                  'Slot at: $slotTimeStr',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        const Divider(),
        ExpansionTile(
          title: Row(
            children: [
              Icon(Icons.bug_report, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Scheduled Notifications (Debug)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          initiallyExpanded: _debugExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _debugExpanded = expanded);
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Header with count and refresh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_scheduledNotifications.length} notification${_scheduledNotifications.length != 1 ? 's' : ''} scheduled',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadScheduledNotifications,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Notification list or empty state
                  if (_scheduledNotifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 48,
                            color: colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications scheduled',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _scheduledNotifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationDebugItem(
                          _scheduledNotifications[index],
                          theme,
                          colorScheme,
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
