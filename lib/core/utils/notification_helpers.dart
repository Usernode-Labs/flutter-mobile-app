import 'package:crypto_mobile_app/core/models/app_notification.dart';
import 'package:crypto_mobile_app/core/providers/notifications_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helper functions for creating notifications
class NotificationHelpers {
  /// Create a sample welcome notification (useful for testing)
  static void createWelcomeNotification(WidgetRef ref) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: 'Welcome!',
        message: 'Notifications are now enabled. You\'ll be notified about blocks, rewards, and more.',
        type: NotificationType.info,
      ),
    );
  }

  /// Create a notification for block produced
  static void notifyBlockProduced(WidgetRef ref, int height, int epoch, int slot) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: 'Block Produced',
        message: 'Produced block at height $height',
        type: NotificationType.blockProduced,
        data: {
          'height': height,
          'epoch': epoch,
          'globalSlot': slot,
        },
      ),
    );
  }

  /// Create a notification for slot won
  static void notifySlotWon(WidgetRef ref, int slot, int epoch) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: 'Slot Won',
        message: 'Won slot $slot in epoch $epoch',
        type: NotificationType.slotWon,
        data: {
          'globalSlot': slot,
          'epoch': epoch,
        },
      ),
    );
  }

  /// Create a notification for transaction sent
  static void notifyTransactionSent(WidgetRef ref, String amount, String recipient) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: 'Transaction Sent',
        message: 'Sent $amount TKN',
        type: NotificationType.transactionSent,
        data: {
          'amount': amount,
          'recipient': recipient,
        },
      ),
    );
  }

  /// Create a notification for transaction received
  static void notifyTransactionReceived(WidgetRef ref, String amount, String sender) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: 'Transaction Received',
        message: 'Received $amount TKN',
        type: NotificationType.transactionReceived,
        data: {
          'amount': amount,
          'sender': sender,
        },
      ),
    );
  }

  /// Create a notification for node sync
  static void notifyNodeSynced(WidgetRef ref, int height) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: 'Node Synced',
        message: 'Node synced to height $height',
        type: NotificationType.nodeSync,
        data: {
          'height': height,
        },
      ),
    );
  }

  /// Create a notification for error
  static void notifyError(WidgetRef ref, String title, String message) {
    final controller = ref.read(notificationsProvider.notifier);
    controller.addNotification(
      AppNotification.create(
        title: title,
        message: message,
        type: NotificationType.error,
      ),
    );
  }
}
