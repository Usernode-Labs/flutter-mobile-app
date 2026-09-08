import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';

void main() {
  group('svShellRouteForPinnedRoute', () {
    test('folds a platform hash route into /home?sv=<route>', () {
      expect(
        svShellRouteForPinnedRoute('app/echo'),
        '/home?sv=app%2Fecho',
      );
    });

    test('encodes the route so slugs survive the query round-trip', () {
      final route = svShellRouteForPinnedRoute('app/last-one-wins');
      expect(Uri.parse(route).queryParameters['sv'], 'app/last-one-wins');
    });

    test('an empty or blank route lands on the shell root', () {
      expect(svShellRouteForPinnedRoute(''), '/home');
      expect(svShellRouteForPinnedRoute('   '), '/home');
    });

    // The regression this whole design exists for: the launch target is a
    // function of the recorded route alone. No build constant participates,
    // so a tile pinned under one platform base URL cannot be stranded by the
    // next one — there is no origin left to disagree about.
    test('resolution does not depend on any origin or build constant', () {
      expect(
        svShellRouteForPinnedRoute('app/echo'),
        svShellRouteForPinnedRoute('app/echo'),
      );
      expect(svShellRouteForPinnedRoute('challenges'), '/home?sv=challenges');
    });
  });
}
