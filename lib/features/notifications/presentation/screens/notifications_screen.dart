import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/providers/notifications_provider.dart';
import 'package:crypto_mobile_app/features/notifications/presentation/widgets/notification_card.dart';
import 'package:crypto_mobile_app/core/models/app_notification.dart';

/// Screen that displays all notifications
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Group notifications by date
  Map<String, List<AppNotification>> _groupNotificationsByDate(
      List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));

    final Map<String, List<AppNotification>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Older': [],
    };

    for (final notification in notifications) {
      final notifDate = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );

      if (notifDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(notification);
      } else if (notifDate.isAtSameMomentAs(yesterday)) {
        grouped['Yesterday']!.add(notification);
      } else if (notifDate.isAfter(thisWeek)) {
        grouped['This Week']!.add(notification);
      } else {
        grouped['Older']!.add(notification);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notificationsState = ref.watch(notificationsProvider);
    final notificationsController = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppAppBar(
        title: 'Notifications',
        showNotifications: false,
        showNodeStatus: false,
        actions: [
          if (notificationsState.notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  notificationsController.markAllAsRead();
                } else if (value == 'clear_all') {
                  _showClearAllDialog(context, notificationsController);
                }
              },
              itemBuilder: (context) => [
                if (notificationsState.unreadCount > 0)
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all'),
                ),
              ],
            ),
        ],
      ),
      body: notificationsState.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : notificationsState.notifications.isEmpty
              ? _buildEmptyState(context, colorScheme, theme)
              : _buildNotificationsList(
                  context,
                  notificationsState.notifications,
                  notificationsController,
                ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications here when\nevents occur in your node',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    List<AppNotification> notifications,
    NotificationsController controller,
  ) {
    final groupedNotifications = _groupNotificationsByDate(notifications);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      itemCount: groupedNotifications.length,
      itemBuilder: (context, groupIndex) {
        final groupKey = groupedNotifications.keys.elementAt(groupIndex);
        final groupNotifications = groupedNotifications[groupKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                groupKey,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Notifications in this group
            ...groupNotifications.map((notification) {
              return NotificationCard(
                notification: notification,
                onTap: () {
                  if (!notification.isRead) {
                    controller.markAsRead(notification.id);
                  }
                  _navigateToRelevantScreen(context, notification);
                },
                onDismiss: () {
                  controller.deleteNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          // Re-add the notification
                          controller.addNotification(notification);
                        },
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _navigateToRelevantScreen(
      BuildContext context, AppNotification notification) {
    // Navigate to relevant screen based on notification type
    switch (notification.type) {
      case NotificationType.blockProduced:
      case NotificationType.slotWon:
      case NotificationType.nodeSync:
        // Could navigate to Node Status Screen
        break;
      case NotificationType.rewardEarned:
        // Could navigate to Rewards Breakdown Screen
        break;
      case NotificationType.transactionSent:
      case NotificationType.transactionReceived:
        // Could navigate to Wallet Screen
        break;
      case NotificationType.error:
      case NotificationType.info:
        // Stay on notifications screen
        break;
    }
  }

  void _showClearAllDialog(
      BuildContext context, NotificationsController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This will permanently delete all notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.clearAll();
              Navigator.of(context).pop();
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}
