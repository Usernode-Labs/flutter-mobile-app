import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS names the app Homeroom wherever the system reads its name', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    String? value(String key) =>
        RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
            .firstMatch(plist)
            ?.group(1);

    // The home screen reads CFBundleDisplayName; some system prompts, such
    // as "… wants to use accounts.google.com to sign in", read CFBundleName,
    // which still said Flutter's default "mobile_app".
    expect(value('CFBundleDisplayName'), 'Homeroom');
    expect(value('CFBundleName'), 'Homeroom');
  });
}
