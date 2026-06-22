import 'package:crypto_mobile_app/features/activity/application/activity_notification_routing.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

const dappNotificationTitleMaxLength = 96;
const dappNotificationBodyMaxLength = 240;
const dappAttentionNotificationTtl = Duration(hours: 24);

class DappNotificationBridgeParseException implements Exception {
  const DappNotificationBridgeParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DappNotificationBridgePayload {
  const DappNotificationBridgePayload._();

  static ActivityEvent parse({
    required Map<String, dynamic> payload,
    required String dappName,
    required String nativeTargetRoute,
  }) {
    final args = payload['args'];
    final data = args is Map
        ? Map<String, Object?>.from(args)
        : Map<String, Object?>.from(payload);

    final title = _boundedText(
      _first(data, 'title', 'subject'),
      maxLength: dappNotificationTitleMaxLength,
    );
    if (title == null) {
      throw const DappNotificationBridgeParseException('title is required');
    }

    final body =
        _boundedText(
          _first(data, 'body', 'message', 'text'),
          maxLength: dappNotificationBodyMaxLength,
        ) ??
        '';
    final requestedCategory = _string(_first(data, 'category', 'type'));
    final requestedPriority = _string(_first(data, 'priority', 'importance'));
    final webRoute = _string(_first(data, 'route', 'url', 'href'));
    final suppliedDedupeKey = _string(_first(data, 'dedupeKey', 'tag'));
    final eventType =
        _string(_first(data, 'eventType', 'kind', 'type')) ?? 'dapp_notify';
    final priority = _priorityFor(requestedPriority);
    final safeTargetRoute = resolveActivityNotificationRoute(nativeTargetRoute);
    final expiresAt =
        _date(_first(data, 'expiresAt', 'expires_at')) ??
        (priority == ActivityPriority.attention
            ? DateTime.now().add(dappAttentionNotificationTtl)
            : null);

    return ActivityEvent(
      source: ActivitySource.dapp,
      category: _categoryFor(requestedCategory),
      eventType: eventType,
      title: title,
      body: body,
      priority: priority,
      targetRoute: safeTargetRoute,
      dedupeKey:
          suppliedDedupeKey ?? _dedupeKey(dappName, eventType, webRoute, title),
      expiresAt: expiresAt,
      payload: {
        'bridgeMethod': 'notify',
        'dappName': dappName,
        if (requestedCategory != null) 'requestedCategory': requestedCategory,
        if (requestedPriority != null) 'requestedPriority': requestedPriority,
        if (webRoute != null) 'webRoute': webRoute,
      },
    );
  }

  static ActivityCategory _categoryFor(String? raw) {
    final value = _normalize(raw);
    return switch (value) {
      'transaction' ||
      'transactions' ||
      'tx' => ActivityCategory.dappTransaction,
      'game' || 'games' => ActivityCategory.dappGame,
      'market' || 'markets' || 'opinionmarket' => ActivityCategory.dappMarket,
      'canvas' || 'art' || 'drawing' => ActivityCategory.dappCanvas,
      'identity' ||
      'auth' ||
      'signature' ||
      'signing' => ActivityCategory.dappIdentity,
      _ => ActivityCategory.dappFeedback,
    };
  }

  static ActivityPriority _priorityFor(String? raw) {
    final value = _normalize(raw);
    return switch (value) {
      'passive' || 'low' => ActivityPriority.passive,
      'attention' || 'high' || 'urgent' => ActivityPriority.attention,
      'persistent' => ActivityPriority.attention,
      _ => ActivityPriority.standard,
    };
  }

  static Object? _first(
    Map<String, Object?> data,
    String a, [
    String? b,
    String? c,
  ]) {
    for (final key in [a, b, c]) {
      if (key == null) continue;
      final value = data[key];
      if (value != null) return value;
    }
    return null;
  }

  static String? _boundedText(Object? value, {required int maxLength}) {
    final text = _string(value)?.replaceAll(RegExp(r'\s+'), ' ');
    if (text == null || text.isEmpty) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3).trimRight()}...';
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) {
    final text = _string(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static String _normalize(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static String _dedupeKey(
    String dappName,
    String eventType,
    String? webRoute,
    String title,
  ) {
    if (webRoute != null) return 'dapp:$dappName:$webRoute';
    final parts = [
      _normalize(dappName),
      _normalize(eventType),
      _normalize(title),
    ];
    return 'dapp:${parts.where((part) => part.isNotEmpty).join(':')}';
  }
}
