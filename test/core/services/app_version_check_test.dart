import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersionCheck store links', () {
    test('the fallback opens the public App Store listing', () {
      expect(
        AppVersionCheck.appStoreUrl,
        'https://apps.apple.com/app/id6814786047',
      );
    });

    test('the fallback opens the public Play listing', () {
      expect(
        AppVersionCheck.playStoreUrl,
        'https://play.google.com/store/apps/details?id=com.onhomeroom.app',
      );
    });
  });
}
