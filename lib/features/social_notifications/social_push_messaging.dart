import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'social_push_store.dart';

abstract interface class SocialPushMessaging {
  Future<String?> initialize();
  Stream<Map<String, Object?>> get foregroundMessages;
  Stream<Map<String, Object?>> get openedMessages;
  Stream<String> get tokenRefreshes;
  Future<Map<String, Object?>?> getInitialOpenedMessage();
  Future<SocialPushPermission> getPermission();
  Future<SocialPushPermission> requestPermission();
  Future<String?> getApnsToken();
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<void> setAutoInitEnabled(bool enabled);
}

class FirebaseSocialPushMessaging implements SocialPushMessaging {
  @override
  Future<String?> initialize() async {
    final app =
        Firebase.apps.isEmpty ? await Firebase.initializeApp() : Firebase.app();
    return app.options.projectId;
  }

  @override
  Stream<Map<String, Object?>> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_data);

  @override
  Stream<Map<String, Object?>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);

  @override
  Stream<String> get tokenRefreshes =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<Map<String, Object?>?> getInitialOpenedMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _data(message);
  }

  @override
  Future<SocialPushPermission> getPermission() async =>
      _permission((await FirebaseMessaging.instance.getNotificationSettings())
          .authorizationStatus);

  @override
  Future<SocialPushPermission> requestPermission() async =>
      _permission((await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ))
          .authorizationStatus);

  @override
  Future<String?> getApnsToken() => FirebaseMessaging.instance.getAPNSToken();

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();

  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      FirebaseMessaging.instance.setAutoInitEnabled(enabled);

  static Map<String, Object?> _data(RemoteMessage message) =>
      Map<String, Object?>.unmodifiable(message.data);

  static SocialPushPermission _permission(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.notDetermined => SocialPushPermission.notDetermined,
        AuthorizationStatus.denied => SocialPushPermission.denied,
        AuthorizationStatus.authorized => SocialPushPermission.authorized,
        AuthorizationStatus.provisional => SocialPushPermission.provisional,
      };
}
