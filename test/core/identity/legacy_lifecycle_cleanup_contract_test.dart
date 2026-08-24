import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reusable lifecycle retains no superseded terminal machinery', () {
    expect(
        File('lib/core/services/app_reset_service.dart').existsSync(), false);
    expect(File('lib/core/identity/sign_out_fence.dart').existsSync(), false);
    expect(File('test/core/identity/sign_out_fence_test.dart').existsSync(),
        false);

    final source = <Directory>[
      Directory('lib'),
      Directory('android/app/src/main'),
      Directory('ios/Runner'),
    ]
        .expand(
          (directory) => directory
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => const {'.dart', '.kt', '.swift'}
                  .contains(_extension(file.path))),
        )
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final obsolete in <String>[
      'AppResetService',
      'NextLaunchWriter',
      'resetAndTerminate',
      'terminatePreservingData',
      'enterTerminalReset',
      'clearNativeResetState',
      'closeForTerminalReset',
      'closeForSignOut',
      'clearForTerminalReset',
      '_terminalResetRequested',
      '_terminallyClosed',
      "'restarting': true",
      'appResetLogoutTitle',
      'appResetSessionExpiredTitle',
      'appResetCredentialMissingTitle',
      'appResetAccountChangedTitle',
      'appResetGuestTitle',
    ]) {
      expect(source, isNot(contains(obsolete)), reason: obsolete);
    }
    expect(source.toLowerCase(), isNot(contains('terminal reset')));
  });
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot);
}
