import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';

const activityNotificationFallbackRoute = '/activity';

String activityNotificationRecordRoute(String recordId) {
  return Uri(
    path: activityNotificationFallbackRoute,
    queryParameters: {'openRecord': recordId},
  ).toString();
}

String resolveActivityNotificationRoute(String? targetRoute) {
  final raw = targetRoute?.trim();
  if (raw == null || raw.isEmpty) return activityNotificationFallbackRoute;

  final uri = Uri.tryParse(raw);
  if (uri == null) return activityNotificationFallbackRoute;
  if (uri.hasScheme && !isUsernodeAppDeepLink(uri)) {
    return activityNotificationFallbackRoute;
  }

  final path = uri.path;
  if (path.isEmpty) return activityNotificationFallbackRoute;

  if (!isAllowedAppDeepLinkPath(path)) return activityNotificationFallbackRoute;

  final openRecord = uri.queryParameters['openRecord']?.trim();
  if (path == activityNotificationFallbackRoute &&
      openRecord != null &&
      openRecord.isNotEmpty) {
    return activityNotificationRecordRoute(openRecord);
  }

  return path;
}

bool hasActivityNotificationDestination(String? targetRoute) {
  return resolveActivityNotificationRoute(targetRoute) !=
      activityNotificationFallbackRoute;
}
