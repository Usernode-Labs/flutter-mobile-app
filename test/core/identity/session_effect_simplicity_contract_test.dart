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
    final appReset =
        File('lib/core/services/app_reset_service.dart').readAsStringSync();

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
      'MobileNode.current',
      'MobileNode.shutdown',
      '_terminalResetRequested',
      'signalShutdownForTerminalReset',
      '_configureWalletSigner',
      'walletSetSignerFromSecret',
    ]) {
      expect(nodeService, isNot(contains(forbidden)));
    }
    expect(appReset, isNot(contains('signalShutdownForTerminalReset')));
  });

  test('sleep shutdown uses its ordinary transition queue without a drain', () {
    final source =
        File('lib/core/services/app_sleep_service.dart').readAsStringSync();

    for (final forbidden in [
      '_sessionGeneration',
      '_sessionSuperseded',
      '_transition.timeout',
      '_activeWakelockPoll.timeout',
    ]) {
      expect(
        source,
        isNot(contains(forbidden)),
        reason: '$forbidden creates a private shutdown protocol',
      );
    }
  });

  test('epoch shutdown uses ordinary cancellation without a terminal latch',
      () {
    final source = File(
      'lib/core/services/epoch_slot_scheduler_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_terminalResetRequested')));
    expect(source, isNot(contains('Terminal reset is in progress')));
  });

  test('session controller has one non-null authority path', () {
    final controller =
        File('lib/core/identity/session_controller.dart').readAsStringSync();
    final gateway = File(
      'lib/core/identity/session_authority_gateway.dart',
    ).readAsStringSync();
    final webview =
        File('lib/features/dapps/dapp_webview_screen.dart').readAsStringSync();

    expect(
      controller,
      contains('required SessionAuthorityGateway sessionAuthority'),
    );
    for (final forbidden in [
      'Provider<SessionAuthorityGateway?>',
      'SessionAuthorityGateway? sessionAuthority',
      'SessionAuthorityGateway? _sessionAuthority',
      '_sessionAuthority != null',
      '_sessionAuthority == null',
      '_restoreAuthenticated',
      '_persistLoginTarget',
      '_endSessionScope',
      '_logoutStoredTokenBestEffort',
    ]) {
      expect(controller, isNot(contains(forbidden)));
    }
    expect(gateway, isNot(contains('identity.sessionId == null')));
    expect(gateway, isNot(contains('identity.credentialRef == null')));
    expect(gateway, isNot(contains('identity.credentialGeneration == null')));
    expect(
      webview,
      isNot(contains('sessionAuthorityGatewayProvider) ??')),
    );
  });
}
