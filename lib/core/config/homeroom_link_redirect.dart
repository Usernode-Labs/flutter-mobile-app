import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';

/// Only the verified website can supply an absolute shell destination. Keep
/// its path, query and fragment intact; never interpret them as native routes.
Uri? homeroomWebLink(Uri uri) {
  if ((uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host != 'app.onhomeroom.com' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  return uri.replace(scheme: 'https', port: 443);
}

/// Flutter delivers cold and warm OS links through the same GoRouter parser.
/// Read its original URI before GoRouter's trailing-slash normalization, and
/// give repeated taps an identity so the running WebView navigates again.
GoRouterRedirect homeroomLinkRedirect(Uri Function() incomingUri) {
  var launch = 0;
  return (context, state) {
    final uri = state.uri;
    if (uri.scheme == 'https' ||
        uri.scheme == 'http' ||
        (!uri.hasScheme && uri.hasAuthority)) {
      final target = homeroomWebLink(incomingUri());
      if (target == null) return AppRoutes.home;
      return Uri(path: AppRoutes.home, queryParameters: {
        'web': target.toString(),
        'launch': 'web-${++launch}',
      }).toString();
    }
    if (shouldBlockHomeroomDeepLink(uri) ||
        state.matchedLocation == AppRoutes.splash) {
      return AppRoutes.home;
    }
    return null;
  };
}
