import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';

void main() {
  group('isAllowedAppDeepLinkPath', () {
    test('allows shipped challenge and dApp routes', () {
      expect(isAllowedAppDeepLinkPath('/challenges/leaderboard'), true);
      expect(isAllowedAppDeepLinkPath('/challenges/zk-identity'), true);
      expect(isAllowedAppDeepLinkPath('/challenges/zk-identity/flow'), true);
      expect(isAllowedAppDeepLinkPath('/dapps'), true);
      expect(isAllowedAppDeepLinkPath('/dapps/opinion-market'), true);
    });

    test('rejects sensitive or unknown routes', () {
      expect(isAllowedAppDeepLinkPath('/wallet/send'), false);
      expect(isAllowedAppDeepLinkPath('/settings'), false);
      expect(isAllowedAppDeepLinkPath('/main/node'), false);
      expect(isAllowedAppDeepLinkPath('/challenges/not-yet-shipped'), false);
      expect(isAllowedAppDeepLinkPath('/dapps/opinion-market/settings'), false);
      expect(isAllowedAppDeepLinkPath('/dappsevil'), false);
    });
  });

  group('isAllowedUsernodeAppDeepLink', () {
    test('allows usernode app links for allowlisted paths', () {
      expect(
        isAllowedUsernodeAppDeepLink(
          Uri.parse('usernode://app/challenges/leaderboard'),
        ),
        true,
      );
      expect(
        isAllowedUsernodeAppDeepLink(
          Uri.parse('usernode://app/dapps/opinion-market'),
        ),
        true,
      );
    });

    test('rejects wrong scheme, host, or path', () {
      expect(
        isAllowedUsernodeAppDeepLink(
          Uri.parse('https://app/challenges/leaderboard'),
        ),
        false,
      );
      expect(
        isAllowedUsernodeAppDeepLink(
          Uri.parse('usernode://other/challenges/leaderboard'),
        ),
        false,
      );
      expect(
        isAllowedUsernodeAppDeepLink(Uri.parse('usernode://app/wallet/send')),
        false,
      );
      expect(
        isAllowedUsernodeAppDeepLink(Uri.parse('usernode:/wallet/send')),
        false,
      );
    });
  });

  group('shouldBlockUsernodeDeepLink', () {
    test('blocks any unsupported usernode scheme URI', () {
      expect(
        shouldBlockUsernodeDeepLink(Uri.parse('usernode://app/wallet/send')),
        true,
      );
      expect(
        shouldBlockUsernodeDeepLink(Uri.parse('usernode:/wallet/send')),
        true,
      );
      expect(
        shouldBlockUsernodeDeepLink(Uri.parse('usernode://other/wallet/send')),
        true,
      );
    });

    test('allows safe usernode app links and ignores non-usernode links', () {
      expect(
        shouldBlockUsernodeDeepLink(
          Uri.parse('usernode://app/challenges/leaderboard'),
        ),
        false,
      );
      expect(
        shouldBlockUsernodeDeepLink(Uri.parse('https://usernode.example')),
        false,
      );
    });
  });
}
