import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary session work has no process permit or handoff adapter', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    for (final forbidden in [
      'SessionEffectPermit',
      'sessionAuthorityAcquireCredentialEffect',
      'sessionAuthorityAcquireAccountEffect',
      'sessionAuthorityAcquireHttpEffect',
      'sessionAuthorityAcquireWorkflowEffect',
      'sessionAuthorityAcquirePushEffect',
      'sessionAuthorityAcquireWebviewEffect',
      'markEffectHandoff',
      'releaseEffectPermit',
      'SessionAuthorityCredentialRequestSender',
      'SessionAuthorityWorkflowCredentialRequestSender',
      'sendCredentialRequest',
      'sendWorkflowCredentialRequest',
    ]) {
      final offenders = sources
          .where((file) => file.readAsStringSync().contains(forbidden))
          .map((file) => file.path)
          .toList();
      expect(offenders, isEmpty, reason: '$forbidden is an ordinary-work gate');
    }

    expect(
      File('lib/core/network/request_written_http_transport.dart').existsSync(),
      isFalse,
      reason: 'ordinary HTTP must use the normal application transport',
    );
  });
}
