import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';

const activityNotificationFallbackRoute = '/activity';
const _challengesRoute = '/challenges';
const _dappsRoute = '/dapps';
const _nodeRoute = '/main/node';
const _profileSettingsRoute = '/profile/settings';

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

String resolveActivityRecordRoute(ActivityRecord record) {
  final resolved = resolveActivityNotificationRoute(record.targetRoute);
  if (resolved != activityNotificationFallbackRoute) return resolved;
  return _sourceRootFallback(record);
}

String _sourceRootFallback(ActivityRecord record) {
  return switch (record.category) {
    ActivityCategory.challengePromotion ||
    ActivityCategory.challengeDeadline ||
    ActivityCategory.rewardActivity => _challengesRoute,
    ActivityCategory.dappTransaction ||
    ActivityCategory.dappGame ||
    ActivityCategory.dappMarket ||
    ActivityCategory.dappCanvas ||
    ActivityCategory.dappFeedback ||
    ActivityCategory.dappIdentity => _dappsRoute,
    ActivityCategory.productionSetup => _profileSettingsRoute,
    ActivityCategory.productionStatus ||
    ActivityCategory.productionResult => _nodeRoute,
  };
}
