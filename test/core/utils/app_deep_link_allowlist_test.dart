import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';

void main() {
  group('isAllowedAppDeepLinkPath', () {
    test('allows the temporary ZK proof and dApp routes', () {
      expect(isAllowedAppDeepLinkPath('/challenges/zk-identity'), true);
      expect(isAllowedAppDeepLinkPath('/challenges/zk-identity/flow'), true);
      expect(isAllowedAppDeepLinkPath('/dapps'), true);
      expect(isAllowedAppDeepLinkPath('/dapps/opinion-market'), true);
    });

    test('allows pinned dapp deep links with hex ids only', () {
      expect(isAllowedAppDeepLinkPath('/dapps/pinned/0a1b2c3d4e5f'), true);
      expect(isAllowedAppDeepLinkPath('/dapps/pinned/'), false);
      expect(isAllowedAppDeepLinkPath('/dapps/pinned/UPPERCASE'), false);
      expect(isAllowedAppDeepLinkPath('/dapps/pinned/abc/extra'), false);
      expect(
        isAllowedAppDeepLinkPath('/dapps/pinned/../../wallet/send'),
        false,
      );
    });

    test('rejects sensitive or unknown routes', () {
      expect(isAllowedAppDeepLinkPath('/wallet/send'), false);
      expect(isAllowedAppDeepLinkPath('/settings'), false);
      expect(isAllowedAppDeepLinkPath('/main/node'), false);
      expect(isAllowedAppDeepLinkPath('/challenges/leaderboard'), false);
      expect(isAllowedAppDeepLinkPath('/challenges/not-yet-shipped'), false);
      expect(isAllowedAppDeepLinkPath('/dapps/opinion-market/settings'), false);
      expect(isAllowedAppDeepLinkPath('/dappsevil'), false);
    });
  });

  group('isAllowedHomeroomAppDeepLink', () {
    test('allows homeroom app links for allowlisted paths', () {
      expect(
        isAllowedHomeroomAppDeepLink(
          Uri.parse('homeroom://app/challenges/zk-identity'),
        ),
        true,
      );
      expect(
        isAllowedHomeroomAppDeepLink(
          Uri.parse('homeroom://app/dapps/opinion-market'),
        ),
        true,
      );
    });

    test('rejects wrong scheme, host, or path', () {
      expect(
        isAllowedHomeroomAppDeepLink(
          Uri.parse('https://app/challenges/zk-identity'),
        ),
        false,
      );
      expect(
        isAllowedHomeroomAppDeepLink(
          Uri.parse('homeroom://other/challenges/zk-identity'),
        ),
        false,
      );
      expect(
        isAllowedHomeroomAppDeepLink(Uri.parse('homeroom://app/wallet/send')),
        false,
      );
      expect(
        isAllowedHomeroomAppDeepLink(Uri.parse('homeroom:/wallet/send')),
        false,
      );
    });
  });

  group('shouldBlockHomeroomDeepLink', () {
    test('blocks any unsupported homeroom scheme URI', () {
      expect(
        shouldBlockHomeroomDeepLink(Uri.parse('homeroom://app/wallet/send')),
        true,
      );
      expect(
        shouldBlockHomeroomDeepLink(Uri.parse('homeroom:/wallet/send')),
        true,
      );
      expect(
        shouldBlockHomeroomDeepLink(Uri.parse('homeroom://other/wallet/send')),
        true,
      );
    });

    test('allows safe homeroom app links and ignores non-homeroom links', () {
      expect(
        shouldBlockHomeroomDeepLink(
          Uri.parse('homeroom://app/challenges/zk-identity'),
        ),
        false,
      );
      expect(
        shouldBlockHomeroomDeepLink(Uri.parse('https://homeroom.example')),
        false,
      );
    });
  });
}
