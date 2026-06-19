import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';

String? resolveDappNotificationWebUrl({
  required String baseUrl,
  required String? webRoute,
}) {
  final base = parseDappUrl(baseUrl);
  final route = _safeWebRoute(webRoute);
  if (route == null) return base.toString();

  if (route.startsWith('#')) {
    return base.replace(fragment: route.substring(1)).toString();
  }

  return base.resolve(route).toString();
}

String? dappSlugFromNotificationWebRoute(String? webRoute) {
  final route = _safeWebRoute(webRoute);
  if (route == null) return null;

  final path = route.startsWith('#') ? route.substring(1) : route;
  final match = RegExp(r'^/?app/([a-z0-9-]+)(?:/|$)').firstMatch(path);
  return match?.group(1);
}

String? _safeWebRoute(String? raw) {
  final route = raw?.trim();
  if (route == null || route.isEmpty) return null;
  if (route.contains(RegExp(r'[\x00-\x1F\x7F]'))) return null;
  if (route.startsWith('//')) return null;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(route)) return null;
  if (route.startsWith('#') || route.startsWith('/')) return route;
  return null;
}
