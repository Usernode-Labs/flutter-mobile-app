import 'dart:io';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Google's sheet returns to the app through the reversed iOS client ID;
  // a scheme for any other client leaves the person stranded in Safari.
  test('iOS URL scheme is the reversed Google iOS client ID', () {
    final xcconfig =
        File('ios/Flutter/GoogleSignIn.xcconfig').readAsStringSync();
    final scheme =
        RegExp(r'^GOOGLE_REVERSED_CLIENT_ID = (\S+)$', multiLine: true)
            .firstMatch(xcconfig)!
            .group(1)!;
    const suffix = '.apps.googleusercontent.com';

    expect(AppConfig.googleIosClientId, endsWith(suffix));
    final id = AppConfig.googleIosClientId
        .substring(0, AppConfig.googleIosClientId.length - suffix.length);
    expect(scheme, 'com.googleusercontent.apps.$id');
  });

  test('Google server and iOS clients share one Cloud project', () {
    String project(String clientId) => clientId.split('-').first;

    expect(AppConfig.googleServerClientId, isNotEmpty);
    expect(
      project(AppConfig.googleIosClientId),
      project(AppConfig.googleServerClientId),
    );
  });
}
