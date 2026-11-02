import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:flutter/widgets.dart';
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

  group('AppVersionCheck.requestBody', () {
    test('names the phone\'s language, so the prompt can come back in it', () {
      expect(
        AppVersionCheck.requestBody(
          os: 'ios',
          appVersion: '1.2.3',
          buildNumber: 45,
          locale: const Locale('pt', 'BR'),
        ),
        {
          'os': 'ios',
          'app_version': '1.2.3',
          'build_number': 45,
          'language': 'pt-BR',
        },
      );
    });
  });

  group('AppVersionCheck.messageDirection', () {
    test('a right-to-left message reads right to left in the English dialog',
        () {
      expect(
        AppVersionCheck.messageDirection('يرجى تحديث التطبيق'),
        TextDirection.rtl,
      );
    });

    test('anything else reads left to right', () {
      expect(
        AppVersionCheck.messageDirection('Please update.'),
        TextDirection.ltr,
      );
    });
  });
}
