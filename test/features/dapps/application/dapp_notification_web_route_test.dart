import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/dapps/application/dapp_notification_web_route.dart';

void main() {
  group('resolveDappNotificationWebUrl', () {
    test('applies safe hash route to the dApp base URL', () {
      expect(
        resolveDappNotificationWebUrl(
          baseUrl: 'https://social-vibecoding.usernodelabs.org/',
          webRoute: '#app/builder-board/dev/sessions/42',
        ),
        'https://social-vibecoding.usernodelabs.org/#app/builder-board/dev/sessions/42',
      );
    });

    test('applies safe relative path to the dApp base URL', () {
      expect(
        resolveDappNotificationWebUrl(
          baseUrl: 'https://example.app/root/',
          webRoute: '/rounds/current',
        ),
        'https://example.app/rounds/current',
      );
    });

    test('rejects absolute and protocol-relative routes', () {
      expect(
        resolveDappNotificationWebUrl(
          baseUrl: 'https://example.app/',
          webRoute: 'https://evil.example/app',
        ),
        'https://example.app/',
      );
      expect(
        resolveDappNotificationWebUrl(
          baseUrl: 'https://example.app/',
          webRoute: '//evil.example/app',
        ),
        'https://example.app/',
      );
      expect(
        resolveDappNotificationWebUrl(
          baseUrl: 'https://example.app/',
          webRoute: 'javascript:alert(1)',
        ),
        'https://example.app/',
      );
    });
  });

  group('dappSlugFromNotificationWebRoute', () {
    test('extracts Social Vibecoding app slug from hash routes', () {
      expect(
        dappSlugFromNotificationWebRoute('#app/builder-board/dev/sessions/42'),
        'builder-board',
      );
    });

    test('returns null for non-app routes', () {
      expect(dappSlugFromNotificationWebRoute('#settings'), isNull);
      expect(dappSlugFromNotificationWebRoute('/rounds/current'), isNull);
    });
  });
}
