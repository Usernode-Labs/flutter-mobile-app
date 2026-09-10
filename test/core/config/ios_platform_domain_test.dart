import 'dart:io';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the platform host is covered by the iOS App-Bound Domains', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final array = RegExp(
      r'<key>WKAppBoundDomains</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(plist);
    expect(array, isNotNull);
    final domains = RegExp(r'<string>([^<]+)</string>')
        .allMatches(array!.group(1)!)
        .map((match) => match.group(1)!);
    final host = Uri.parse(AppConfig.platformBaseUrl).host;
    expect(
      domains.any((domain) => host == domain || host.endsWith('.$domain')),
      isTrue,
      reason: '$host must be allowed before the iOS WebView can load it',
    );
  });
}
