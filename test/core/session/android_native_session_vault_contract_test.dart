import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native cold recovery stays local and preserves claim ownership',
      () async {
    final source = await File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/session/'
      'AndroidNativeSessionVault.kt',
    ).readAsString();

    final foreground = RegExp(
      r'fun stageInteractiveColdInstalledCredential\(\): ColdCredentialStage \{([\s\S]*?)\n    \}',
    ).firstMatch(source);
    final background = RegExp(
      r'fun stageBackgroundColdInstalledCredential\(\): ColdCredentialStage \{([\s\S]*?)\n    \}',
    ).firstMatch(source);

    expect(
      foreground?.group(1),
      contains('NativeSessionRust.nativeStageInstalledCredential(frame)'),
    );
    expect(
      foreground?.group(1),
      isNot(contains('nativeStageColdInstalledCredentialV1')),
    );
    expect(
      background?.group(1),
      contains('NativeSessionRust.nativeStageColdInstalledCredentialV1(frame)'),
    );

    final localStart = source.indexOf(
      'private fun stageLocalInstalledCredential(',
    );
    final localEnd = source.indexOf(
      '/** Fetches and stages one exact policy claim',
      localStart,
    );
    expect(localStart, greaterThanOrEqualTo(0));
    expect(localEnd, greaterThan(localStart));

    final localRecovery = source.substring(localStart, localEnd);
    expect(localRecovery, contains('recoverCredential(storedRaw)'));
    expect(localRecovery, isNot(contains('authenticatedProducerMaterial()')));
    expect(localRecovery, isNot(contains('configuredHttp()')));

    final iosSource =
        await File('ios/Runner/NativeSessionVault.swift').readAsString();
    final iosInteractive = RegExp(
      r'func stageInteractiveColdInstalledCredential\(\) -> IOSColdCredentialStage \{([\s\S]*?)\n  \}',
    ).firstMatch(iosSource);
    final iosBackground = RegExp(
      r'func stageBackgroundColdInstalledCredential\(\) -> IOSColdCredentialStage \{([\s\S]*?)\n  \}',
    ).firstMatch(iosSource);

    expect(
      iosInteractive?.group(1),
      contains('IOSNativeSessionRust.stageInstalledCredential(&frame)'),
    );
    expect(
      iosInteractive?.group(1),
      isNot(contains('stageColdInstalledCredential')),
    );
    expect(
      iosBackground?.group(1),
      contains('IOSNativeSessionRust.stageColdInstalledCredential(&frame)'),
    );
  });
}
