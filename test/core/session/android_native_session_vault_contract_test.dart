import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android cold session recovery stays local', () async {
    final source = await File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/session/'
      'AndroidNativeSessionVault.kt',
    ).readAsString();

    final foreground = RegExp(
      r'fun stageColdInstalledCredential\(\): ColdCredentialStage \{\s*'
      r'return ([A-Za-z0-9_]+\(\))\s*\}',
    ).firstMatch(source);
    final background = RegExp(
      r'fun stageBackgroundColdInstalledCredential\(\): ColdCredentialStage \{\s*'
      r'return ([A-Za-z0-9_]+\(\))\s*\}',
    ).firstMatch(source);

    expect(foreground?.group(1), 'stageLocalColdInstalledCredential()');
    expect(background?.group(1), 'stageLocalColdInstalledCredential()');

    final localStart = source.indexOf(
      'private fun stageLocalColdInstalledCredential()',
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
  });
}
