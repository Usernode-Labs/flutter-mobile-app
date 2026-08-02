import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';

void main() {
  group('NodeLifecycleCoordinator', () {
    late List<String> calls;

    NodeLifecycleCoordinator build({
      required bool android,
      bool startResult = true,
    }) {
      calls = [];
      return NodeLifecycleCoordinator(
        startBackend: () async {
          calls.add('startBackend');
          return startResult;
        },
        stopBackend: () async => calls.add('stopBackend'),
        enableWatchdogRecovery: () => calls.add('enableRecovery'),
        disableWatchdogRecovery: () => calls.add('disableRecovery'),
        auditBestEffort: ({required String reason}) =>
            calls.add('audit:$reason'),
        onNodeStarted: () async => calls.add('onNodeStarted'),
        stopMonitoring: ({required String reason}) async =>
            calls.add('stopMonitoring:$reason'),
        cancelAllAlarms: () async => calls.add('cancelAllAlarms'),
        cancelAlarmWatchdog: () async => calls.add('cancelWatchdog'),
        isAndroid: () => android,
      );
    }

    test(
        'successful Android start re-arms recovery, audits, then wires '
        'the foreground service', () async {
      final coordinator = build(android: true);

      final started = await coordinator.startNode(reason: 'platform_start');

      expect(started, isTrue);
      expect(calls, [
        'startBackend',
        // Recovery must be enabled before onNodeStarted so the controller's
        // own re-arm check doesn't queue a duplicate audit.
        'enableRecovery',
        'audit:platform_start',
        'onNodeStarted',
      ]);
    });

    test(
        'failed Android start disables recovery and cancels the watchdog '
        'instead of wiring production support', () async {
      final coordinator = build(android: true, startResult: false);

      final started = await coordinator.startNode(reason: 'platform_start');

      expect(started, isFalse);
      expect(calls, ['startBackend', 'disableRecovery', 'cancelWatchdog']);
    });

    test('non-Android start touches only the backend', () async {
      final coordinator = build(android: false);

      final started =
          await coordinator.startNode(reason: 'standalone_dapp_entry');

      expect(started, isTrue);
      expect(calls, ['startBackend']);
    });

    test(
        'Android stop disables recovery before stopping and cancels alarms '
        'after the runtime is down', () async {
      final coordinator = build(android: true);

      await coordinator.stopNode(reason: 'platform_stop');

      expect(calls, [
        'disableRecovery',
        'stopMonitoring:platform_stop',
        'stopBackend',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
    });

    test('non-Android stop touches only the backend', () async {
      final coordinator = build(android: false);

      await coordinator.stopNode(reason: 'account_removed');

      expect(calls, ['stopBackend']);
    });
  });
}
