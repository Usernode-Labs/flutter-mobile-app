import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';

void main() {
  const sv = 'https://social-vibecoding.usernodelabs.org';

  group('svShellRouteForPinnedDappUrl', () {
    test('remaps an SV hash-route pin into /home?sv=<fragment>', () {
      expect(
        svShellRouteForPinnedDappUrl(
          pinnedUrl: '$sv/#app/echo',
          dappsTabUrl: sv,
        ),
        '/home?sv=app%2Fecho',
      );
    });

    test('encodes fragments so slugs survive the query round-trip', () {
      final route = svShellRouteForPinnedDappUrl(
        pinnedUrl: '$sv/#app/last-one-wins',
        dappsTabUrl: sv,
      )!;
      final sv0 = Uri.parse(route).queryParameters['sv'];
      expect(sv0, 'app/last-one-wins');
    });

    test('SV root pin (no fragment) goes home', () {
      expect(
        svShellRouteForPinnedDappUrl(pinnedUrl: sv, dappsTabUrl: sv),
        '/home',
      );
    });

    test('root slash and empty root path are equivalent', () {
      expect(
        svShellRouteForPinnedDappUrl(
          pinnedUrl: '$sv/#app/echo',
          dappsTabUrl: '$sv/',
        ),
        '/home?sv=app%2Fecho',
      );
    });

    test('SV pins with path or query keep the standalone fallback', () {
      for (final pinnedUrl in [
        '$sv/app/echo',
        '$sv/?view=echo',
        '$sv/app/echo?view=full#details',
      ]) {
        expect(
          svShellRouteForPinnedDappUrl(pinnedUrl: pinnedUrl, dappsTabUrl: sv),
          isNull,
          reason: pinnedUrl,
        );
      }
    });

    test('non-SV origins keep the standalone dapp browser', () {
      expect(
        svShellRouteForPinnedDappUrl(
          pinnedUrl: 'https://echo.usernodelabs.org/#app/echo',
          dappsTabUrl: sv,
        ),
        isNull,
      );
    });

    test('origin match is exact: scheme and port count', () {
      expect(
        svShellRouteForPinnedDappUrl(
          pinnedUrl: 'http://social-vibecoding.usernodelabs.org/#app/echo',
          dappsTabUrl: sv,
        ),
        isNull,
      );
      expect(
        svShellRouteForPinnedDappUrl(
          pinnedUrl: '$sv:8443/#app/echo',
          dappsTabUrl: sv,
        ),
        isNull,
      );
    });

    test('local-dev SV origins remap too (same host, same port)', () {
      expect(
        svShellRouteForPinnedDappUrl(
          pinnedUrl: 'http://localhost:8000/#app/echo',
          dappsTabUrl: 'http://localhost:8000',
        ),
        '/home?sv=app%2Fecho',
      );
    });

    test('garbage input falls back to the standalone browser', () {
      expect(
        svShellRouteForPinnedDappUrl(pinnedUrl: '', dappsTabUrl: sv),
        isNull,
      );
      expect(
        svShellRouteForPinnedDappUrl(pinnedUrl: 'not a url', dappsTabUrl: sv),
        isNull,
      );
    });
  });
}
