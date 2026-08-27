import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
    test('${platform.name} skips mobile-store version checks', () async {
      debugDefaultTargetPlatformOverride = platform;

      expect(await AppVersionCheck.instance.check(), isNull);
    });
  }
}
