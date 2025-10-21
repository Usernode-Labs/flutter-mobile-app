import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/models/app_notification.dart';
import 'package:crypto_mobile_app/core/data/notifications_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// State for notifications
class NotificationsState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    required this.notifications,
    required this.unreadCount,
    this.isLoading = false,
  });

  const NotificationsState.initial()
      : notifications = const [],
        unreadCount = 0,
        isLoading = true;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Create state from list of notifications
  factory NotificationsState.fromNotifications(
      List<AppNotification> notifications) {
    final unreadCount = notifications.where((n) => !n.isRead).length;
    return NotificationsState(
      notifications: notifications,
      unreadCount: unreadCount,
      isLoading: false,
    );
  }
}

/// Controller for managing notifications
class NotificationsController extends Notifier<NotificationsState> {
  final _repository = NotificationsRepository();

  @override
  NotificationsState build() {
    // Load notifications asynchronously
    _loadNotifications();
    return const NotificationsState.initial();
  }

  /// Load notifications from persistent storage
  Future<void> _loadNotifications() async {
    try {
      LoggingService.instance
          .debug('Loading notifications from storage', tag: 'NOTIFICATIONS');
      final notifications = await _repository.load();

      // Sort by timestamp (most recent first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = NotificationsState.fromNotifications(notifications);
      LoggingService.instance.trace(
          'Loaded ${notifications.length} notifications, ${state.unreadCount} unread',
          tag: 'NOTIFICATIONS');
    } catch (e, st) {
      LoggingService.instance.error('Failed to load notifications',
          tag: 'NOTIFICATIONS', error: e, stackTrace: st);
      state = const NotificationsState(
        notifications: [],
        unreadCount: 0,
        isLoading: false,
      );
    }
  }

  /// Add a new notification
  Future<void> addNotification(AppNotification notification) async {
    try {
      LoggingService.instance.trace(
          'Adding notification: ${notification.title}',
          tag: 'NOTIFICATIONS');

      // Add to the beginning of the list (most recent first)
      final updatedNotifications = [notification, ...state.notifications];

      // Update state immediately
      state = NotificationsState.fromNotifications(updatedNotifications);

      // Persist to storage
      await _repository.save(updatedNotifications);

      LoggingService.instance.trace(
          'Notification added successfully. Total: ${updatedNotifications.length}',
          tag: 'NOTIFICATIONS');
    } catch (e, st) {
      LoggingService.instance.error('Failed to add notification',
          tag: 'NOTIFICATIONS', error: e, stackTrace: st);
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String id) async {
    try {
      LoggingService.instance
          .debug('Marking notification as read: $id', tag: 'NOTIFICATIONS');

      final updatedNotifications = state.notifications.map((n) {
        return n.id == id ? n.copyWith(isRead: true) : n;
      }).toList();

      state = NotificationsState.fromNotifications(updatedNotifications);
      await _repository.save(updatedNotifications);

      LoggingService.instance
          .debug('Notification marked as read', tag: 'NOTIFICATIONS');
    } catch (e, st) {
      LoggingService.instance.error('Failed to mark notification as read',
          tag: 'NOTIFICATIONS', error: e, stackTrace: st);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      LoggingService.instance
          .debug('Marking all notifications as read', tag: 'NOTIFICATIONS');

      final updatedNotifications =
          state.notifications.map((n) => n.copyWith(isRead: true)).toList();

      state = NotificationsState.fromNotifications(updatedNotifications);
      await _repository.save(updatedNotifications);

      LoggingService.instance
          .debug('All notifications marked as read', tag: 'NOTIFICATIONS');
    } catch (e, st) {
      LoggingService.instance.error('Failed to mark all notifications as read',
          tag: 'NOTIFICATIONS', error: e, stackTrace: st);
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String id) async {
    try {
      LoggingService.instance
          .debug('Deleting notification: $id', tag: 'NOTIFICATIONS');

      final updatedNotifications =
          state.notifications.where((n) => n.id != id).toList();

      state = NotificationsState.fromNotifications(updatedNotifications);
      await _repository.save(updatedNotifications);

      LoggingService.instance.trace(
          'Notification deleted. Remaining: ${updatedNotifications.length}',
          tag: 'NOTIFICATIONS');
    } catch (e, st) {
      LoggingService.instance.error('Failed to delete notification',
          tag: 'NOTIFICATIONS', error: e, stackTrace: st);
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      LoggingService.instance
          .debug('Clearing all notifications', tag: 'NOTIFICATIONS');

      state = const NotificationsState(
        notifications: [],
        unreadCount: 0,
        isLoading: false,
      );

      await _repository.clear();

      LoggingService.instance
          .debug('All notifications cleared', tag: 'NOTIFICATIONS');
    } catch (e, st) {
      LoggingService.instance.error('Failed to clear all notifications',
          tag: 'NOTIFICATIONS', error: e, stackTrace: st);
    }
  }

  /// Refresh notifications (reload from storage)
  Future<void> refresh() async {
    await _loadNotifications();
  }
}

/// Provider for notifications
final notificationsProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);
