import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session work has no per-effect permit lease or handoff adapter', () {
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
      'retireProducerLeases',
      'retireMonitoringSession',
      '_monitoringGeneration',
      '_watchdogLifecycleGeneration',
      '_superseded(',
      'settleAudit',
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

  test('node lifecycle uses the one Rust supervisor and builder-owned signer',
      () {
    final nodeService =
        File('lib/features/node/node_service.dart').readAsStringSync();

    for (final required in [
      'MobileNode.startAuthoritative',
      'MobileNode.stopIfAuthoritative',
      'MobileNode.pauseIfAuthoritative',
      'MobileNode.resumeIfAuthoritative',
      'builder.walletSignerSecretKey',
    ]) {
      expect(nodeService, contains(required));
    }
    for (final forbidden in [
      'Node.getGlobal',
      'Node.getGlobalControl',
      'runForeverInNewThread',
      '_configureWalletSigner',
      'walletSetSignerFromSecret',
    ]) {
      expect(nodeService, isNot(contains(forbidden)));
    }
  });
}
