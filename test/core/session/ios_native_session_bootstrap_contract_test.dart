import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS root bootstrap requires usable foreground storage', () async {
    final dartSource = await File(
      'lib/src/session_lifecycle/native_session_transport.dart',
    ).readAsString();
    final platformSource = await File(
      'ios/Runner/NativeSessionPlatform.swift',
    ).readAsString();
    final vaultSource = await File(
      'ios/Runner/NativeSessionVault.swift',
    ).readAsString();

    final admission = dartSource.indexOf(
      'await _waitForInteractiveSessionBootstrapAdmission()',
    );
    final platform = dartSource.indexOf(
      'final platform = _NativeSessionPlatformPort()',
    );
    expect(admission, greaterThanOrEqualTo(0));
    expect(platform, greaterThan(admission));
    expect(dartSource, contains('Platform.isIOS'));
    expect(dartSource, contains('AppLifecycleState.resumed'));
    expect(
      platformSource,
      contains('UIApplication.shared.applicationState == .active'),
    );
    expect(
      platformSource,
      contains('UIApplication.shared.isProtectedDataAvailable'),
    );
    expect(vaultSource, isNot(contains('synchronize()')));
  });

  test('process-root bootstrap preserves native platform failures', () async {
    final source = await File(
      'lib/src/session_lifecycle/native_session_transport.dart',
    ).readAsString();

    expect(
      source,
      contains("await _invokePlatform(\n      'bootstrapInteractiveRoot'"),
    );
    expect(source, contains('on PlatformException catch (error)'));
    expect(source, contains("details['code'] ?? error.code"));
  });
}
