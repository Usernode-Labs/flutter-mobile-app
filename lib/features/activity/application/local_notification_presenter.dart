import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_navigator.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_notification_routing.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

class LocalNotificationPresenter implements ActivityNotificationPresenter {
  LocalNotificationPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> show(ActivityRecord record) async {
    await _initialize();
    if (!await _canShowNotifications()) return;

    await _plugin.show(
      id: _notificationId(record),
      title: record.title,
      body: record.body,
      notificationDetails: _notificationDetails(record),
      payload: _notificationPayload(record),
    );
  }

  @override
  Future<void> cancel(ActivityRecord record) async {
    await _initialize();
    await _plugin.cancel(id: _notificationId(record));
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('launch_background');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _openPayloadRoute(response.payload);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _openPayloadRoute(launch?.notificationResponse?.payload);
    }

    _initialized = true;
  }

  Future<bool> _canShowNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? false;
  }

  NotificationDetails _notificationDetails(ActivityRecord record) {
    final importance = switch (record.priority) {
      ActivityPriority.passive => Importance.low,
      ActivityPriority.standard => Importance.defaultImportance,
      ActivityPriority.attention => Importance.high,
      ActivityPriority.persistent => Importance.high,
    };
    final priority = switch (record.priority) {
      ActivityPriority.passive => Priority.low,
      ActivityPriority.standard => Priority.defaultPriority,
      ActivityPriority.attention => Priority.high,
      ActivityPriority.persistent => Priority.high,
    };

    final android = AndroidNotificationDetails(
      record.category.channelId,
      record.category.channelName,
      channelDescription: 'Usernode ${record.category.channelName}',
      importance: importance,
      priority: priority,
      category: AndroidNotificationCategory.status,
      onlyAlertOnce: record.priority == ActivityPriority.persistent,
      ongoing: record.priority == ActivityPriority.persistent,
    );
    final darwin = DarwinNotificationDetails(
      threadIdentifier: record.category.channelId,
    );

    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  static int _notificationId(ActivityRecord record) {
    return record.systemNotificationId ?? record.id.hashCode;
  }

  static String _notificationPayload(ActivityRecord record) {
    if (record.source == ActivitySource.dapp && record.hasDestination) {
      return activityNotificationRecordRoute(record.id);
    }
    return resolveActivityNotificationRoute(record.notificationRoute);
  }

  static void _openPayloadRoute(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final route = resolveActivityNotificationRoute(payload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = appNavigatorKey.currentContext;
      if (context == null) return;
      GoRouter.of(context).go(route);
    });
  }
}
