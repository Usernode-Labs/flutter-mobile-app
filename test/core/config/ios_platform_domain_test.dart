import 'dart:io';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> appBoundDomains() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final array = RegExp(
    r'<key>WKAppBoundDomains</key>\s*<array>([\s\S]*?)</array>',
  ).firstMatch(plist);
  expect(array, isNotNull);
  return RegExp(r'<string>([^<]+)</string>')
      .allMatches(array!.group(1)!)
      .map((match) => match.group(1)!)
      .toList();
}

void main() {
  test('the platform host is covered by the iOS App-Bound Domains', () {
    final domains = appBoundDomains();
    final host = Uri.parse(AppConfig.platformBaseUrl).host;
    expect(
      domains.any((domain) => host == domain || host.endsWith('.$domain')),
      isTrue,
      reason: '$host must be allowed before the iOS WebView can load it',
    );
  });

  test('the apps and previews domains are covered by the iOS App-Bound Domains',
      () {
    // Homeroom serves generated apps on onhomeroom.app, a different site
    // from the platform, and shows them in frames inside the platform's
    // page; previews are to move to onhomeroom.dev, a site of their own.
    // The dapp WebView limits navigations to the App-Bound Domains, so a
    // frame on a domain not listed never loads.
    expect(
      appBoundDomains(),
      containsAll(<String>['onhomeroom.app', 'onhomeroom.dev']),
      reason: 'apps and previews inside Homeroom load from those domains',
    );
  });
}
