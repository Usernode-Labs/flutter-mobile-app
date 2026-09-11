import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('producer reconciliation cannot hold the first Flutter frame', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final runAppAt = mainSource.indexOf('  runApp(');
    final nativeSessionPublishedAt = mainSource.indexOf(
      'void _publishNativeSession(',
      runAppAt,
    );
    expect(runAppAt, greaterThanOrEqualTo(0));
    expect(nativeSessionPublishedAt, greaterThan(runAppAt));
    expect(
      mainSource.substring(0, runAppAt),
      contains('final nativeSessionFuture = () async'),
    );
    expect(
      mainSource.substring(runAppAt, nativeSessionPublishedAt),
      contains('_NativeSessionBootstrapApp(nativeSessionFuture)'),
    );
    expect(
      mainSource.substring(nativeSessionPublishedAt),
      contains('WidgetsBinding.instance.addPostFrameCallback'),
    );

    final transport =
        File('lib/src/session_lifecycle/native_session_transport.dart')
            .readAsStringSync();
    final readyRootStart = transport.indexOf(
      'static Future<_NativeSessionCompositionRoot> _readyRoot(',
    );
    final readyRootEnd = transport.indexOf(
      '\n  final native.ProcessRootClient _root;',
      readyRootStart,
    );
    final readyRoot = transport.substring(readyRootStart, readyRootEnd);
    expect(readyRoot, contains('runtime._foregroundAdmission.suspend()'));
    expect(readyRoot, isNot(contains('runInteractiveProducerWake')));
    expect(readyRoot, isNot(contains('reconcileAfterForegroundResume')));

    final appBuildStart = mainSource.indexOf(
      '  Widget build(BuildContext context)',
    );
    final appBuildEnd = mainSource.indexOf(
      '\n}\n\nfinal class _NodePermissionGateBinding',
      appBuildStart,
    );
    final appBuild = mainSource.substring(appBuildStart, appBuildEnd);
    expect(appBuild, isNot(contains('AbsorbPointer')));
    expect(appBuild, isNot(contains('ModalBarrier')));
  });

  test('native session bootstrap and teardown do not block Android main', () {
    final channel = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/session/'
      'InteractiveNativeSessionChannel.kt',
    ).readAsStringSync();

    for (final method in ['clearOrphanedState', 'retireCredential']) {
      final start = channel.indexOf('private fun $method(');
      final end = channel.indexOf('\n    private fun ', start + 1);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      expect(channel.substring(start, end), contains('runWorker(result)'));
    }

    final vault = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/session/'
      'AndroidNativeSessionVault.kt',
    ).readAsStringSync();
    final configureStart = vault.indexOf('fun configureMobileApiBaseUrl(');
    final configureEnd = vault.indexOf('\n    private fun ', configureStart);
    final configure = vault.substring(configureStart, configureEnd);
    expect(
      configure.indexOf(
        'if (canonicalMobileApiBaseUrl == configured.canonicalBaseUrl) return',
      ),
      lessThan(configure.indexOf('synchronized(this)')),
    );
  });

  test('boot recovery does not enqueue two immediate producer wakes', () {
    final receiver = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
      'AlarmReceiver.kt',
    ).readAsStringSync();

    for (final method in ['handleBootCompleted', 'handlePackageReplaced']) {
      final start = receiver.indexOf('private fun $method(');
      final end = receiver.indexOf('\n    private fun ', start + 1);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final body = receiver.substring(start, end);
      expect(body, contains('NativeProducerWakeCoordinator.submit'));
      expect(body, isNot(contains('enqueueOneTime')));
    }
  });
}
