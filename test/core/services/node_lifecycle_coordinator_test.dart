import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';

void main() {
  group('NodeLifecycleCoordinator desired-state derivation', () {
    // (hasAccount, intent, sleeping, delegated) →
    // (runDesired, recoveryDesired)
    const cases = <(bool, PlatformNodeIntent, bool, bool, bool, bool)>[
      // No account: nothing is ever desired, regardless of intent.
      (false, PlatformNodeIntent.unset, false, false, false, false),
      (false, PlatformNodeIntent.start, false, false, false, false),
      (false, PlatformNodeIntent.stop, false, false, false, false),
      // Account, no platform request yet: recovery armed, no active start.
      (true, PlatformNodeIntent.unset, false, false, false, true),
      (true, PlatformNodeIntent.unset, true, false, false, true),
      // Account + explicit start: run, unless sleeping (recovery stays armed
      // either way — alarm handlers do their own sleep gating).
      (true, PlatformNodeIntent.start, false, false, true, true),
      (true, PlatformNodeIntent.start, true, false, false, true),
      // Delegation preserves node runtime intent but disables producer recovery.
      (true, PlatformNodeIntent.start, false, true, true, false),
      // Account + explicit stop: nothing desired.
      (true, PlatformNodeIntent.stop, false, false, false, false),
    ];

    for (final (hasAccount, intent, sleeping, delegated, wantRun, wantRecovery)
        in cases) {
      test(
          'hasAccount=$hasAccount intent=${intent.name} sleeping=$sleeping '
          'delegated=$delegated '
          '→ run=$wantRun recovery=$wantRecovery', () {
        expect(
          NodeLifecycleCoordinator.runDesired(
            hasAccount: hasAccount,
            intent: intent,
            sleeping: sleeping,
          ),
          wantRun,
        );
        expect(
          NodeLifecycleCoordinator.recoveryDesired(
            hasAccount: hasAccount,
            intent: intent,
            delegated: delegated,
          ),
          wantRecovery,
        );
      });
    }
  });

  group('NodeLifecycleCoordinator reconcile', () {
    late List<String> calls;

    NodeLifecycleCoordinator build({
      required bool android,
      bool startResult = true,
      bool nodeRunning = false,
      bool sleeping = false,
      bool delegated = false,
      Future<bool> Function()? startBackend,
    }) {
      calls = [];
      return NodeLifecycleCoordinator(
        startBackend: startBackend ??
            () async {
              calls.add('startBackend');
              return startResult;
            },
        restartBackend: () async => calls.add('restartBackend'),
        stopBackend: () async => calls.add('stopBackend'),
        isNodeRunning: () => nodeRunning,
        isSleeping: () => sleeping,
        enableWatchdogRecovery: () => calls.add('enableRecovery'),
        disableWatchdogRecovery: () => calls.add('disableRecovery'),
        auditBestEffort: ({required String reason}) =>
            calls.add('audit:$reason'),
        onNodeStarted: () async => calls.add('onNodeStarted'),
        stopMonitoring: ({
          required String reason,
          bool destroyBackgroundEngine = true,
        }) async =>
            calls.add('stopMonitoring:$reason'
                '${destroyBackgroundEngine ? '' : ':keepEngine'}'),
        cancelAllAlarms: () async => calls.add('cancelAllAlarms'),
        cancelAlarmWatchdog: () async => calls.add('cancelWatchdog'),
        isAndroid: () => android,
        isDelegated: () async => delegated,
        retireProducerLeases: () => calls.add('retireProducerLeases'),
        settleAudit: () async => calls.add('settleAudit'),
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

    test('delegated Android start keeps node running without producer support',
        () async {
      final coordinator = build(android: true, delegated: true);

      final started = await coordinator.startNode(reason: 'platform_start');

      expect(started, isTrue);
      expect(calls, [
        'startBackend',
        'disableRecovery',
        'stopMonitoring:platform_start',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
    });

    test('delegation change rebuilds a running node and disarms production',
        () async {
      final coordinator = build(
        android: true,
        nodeRunning: true,
        delegated: true,
      );
      await coordinator.reportColdBoot(hasAccount: true);
      calls.clear();

      await coordinator.reconfigureForDelegationChange();

      expect(calls, [
        'restartBackend',
        'disableRecovery',
        'stopMonitoring:delegation_changed',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
    });

    test('delegation change does not start a stopped node', () async {
      final coordinator = build(android: true, delegated: true);
      await coordinator.reportColdBoot(hasAccount: true);
      calls.clear();

      await coordinator.reconfigureForDelegationChange();

      expect(calls, [
        'disableRecovery',
        'stopMonitoring:delegation_changed',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
    });

    test(
        'Android stop disables recovery before stopping and cancels alarms '
        'after the runtime is down', () async {
      final coordinator = build(android: true);

      await coordinator.stopNode(reason: 'platform_stop');

      expect(calls, [
        'disableRecovery',
        'stopMonitoring:platform_stop',
        'settleAudit',
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

    test(
        'cold boot with an account and a stopped node arms recovery without '
        'starting the node or auditing', () async {
      final coordinator = build(android: true);

      final running =
          await coordinator.reportColdBoot(hasAccount: true, reason: 'boot');

      expect(running, isFalse);
      // No startBackend (start is deferred to the platform), no audit
      // (nothing to reconcile against a stopped runtime), no watchdog
      // cancel (headless recovery must stay possible).
      expect(calls, ['enableRecovery']);
    });

    test(
        'cold boot with an account and an already-running node wires '
        'production support without restarting the backend', () async {
      final coordinator = build(android: true, nodeRunning: true);

      final running =
          await coordinator.reportColdBoot(hasAccount: true, reason: 'boot');

      expect(running, isTrue);
      expect(calls, ['enableRecovery', 'audit:boot', 'onNodeStarted']);
    });

    test('cold boot without an account tears down production support',
        () async {
      final coordinator = build(android: true);

      final running =
          await coordinator.reportColdBoot(hasAccount: false, reason: 'boot');

      expect(running, isFalse);
      expect(calls, [
        'disableRecovery',
        'stopMonitoring:boot',
        'settleAudit',
        'stopBackend',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
    });

    test('account creation arms recovery without starting the node', () async {
      final coordinator = build(android: true);

      await coordinator.reportAccountsChanged(
        hasAccount: true,
        reason: 'account_added',
      );

      expect(calls, ['enableRecovery']);
    });

    test(
        'account removal tears everything down and resets any platform '
        'start intent', () async {
      final coordinator = build(android: true);
      await coordinator.startNode(reason: 'platform_start');
      calls.clear();

      await coordinator.reportAccountsChanged(
        hasAccount: false,
        reason: 'account_removed',
      );

      expect(calls, [
        'disableRecovery',
        'stopMonitoring:account_removed',
        'settleAudit',
        'stopBackend',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
      // A later login must request the start explicitly.
      expect(coordinator.intent, PlatformNodeIntent.unset);
    });

    test(
        'platform start during active app sleep keeps recovery armed but '
        'does not start the node', () async {
      final coordinator = build(android: true, sleeping: true);

      final started = await coordinator.startNode(reason: 'platform_start');

      expect(started, isFalse);
      expect(calls, ['enableRecovery']);
    });

    test('platform start after a platform stop starts the node again',
        () async {
      final coordinator = build(android: true);
      await coordinator.stopNode(reason: 'platform_stop');
      calls.clear();

      final started = await coordinator.startNode(reason: 'platform_start');

      expect(started, isTrue);
      expect(calls, [
        'startBackend',
        'enableRecovery',
        'audit:platform_start',
        'onNodeStarted',
      ]);
    });

    test(
        'standing down for an identity boundary tears the whole producer '
        'lifecycle down, not just the backend', () async {
      final coordinator = build(android: true, nodeRunning: true);
      await coordinator.startNode(reason: 'platform_start');
      calls.clear();

      await coordinator.standDown(reason: 'identity_boundary');

      // Watchdog recovery, Android monitoring, the backend, every scheduled
      // alarm and the alarm watchdog — a `RustBackendService.stopNode()` would
      // have left all but one of these armed for the retired account.
      expect(calls, [
        // Producer leases are retired synchronously before any of this, so a
        // continuation already past its admission check stops short.
        'retireProducerLeases',
        'disableRecovery',
        // Never destroys the cached headless engine: this boundary can be
        // running inside it.
        'stopMonitoring:identity_boundary:keepEngine',
        'settleAudit',
        'stopBackend',
        'cancelAllAlarms',
        'cancelWatchdog',
      ]);
      expect(coordinator.hasAccount, isFalse);
      expect(coordinator.intent, PlatformNodeIntent.unset);
    });

    test('a stand-down leaves admission open for the next session', () async {
      final coordinator = build(android: true);
      await coordinator.standDown(reason: 'identity_boundary');
      calls.clear();

      expect(coordinator.acceptingRuntimeWork, isTrue);
      expect(await coordinator.startNode(reason: 'next_login'), isTrue);
      expect(calls, contains('startBackend'));
    });

    test('a headless recovery event cannot re-arm a stood-down runtime',
        () async {
      final coordinator = build(android: true, nodeRunning: true);
      await coordinator.startNode(reason: 'platform_start');
      await coordinator.standDown(reason: 'identity_boundary');
      calls.clear();

      // The account-presence signal a background/headless path reports is not
      // an explicit platform start, so nothing comes back up and recovery
      // stays disarmed for the retired account.
      await coordinator.reportAccountsChanged(hasAccount: false);
      await coordinator.reportColdBoot(hasAccount: false);

      expect(calls, isNot(contains('startBackend')));
      expect(calls, isNot(contains('enableRecovery')));
    });

    test('a stand-down supersedes an in-flight start', () async {
      final startEntered = Completer<void>();
      final allowStart = Completer<void>();
      final coordinator = build(
        android: true,
        startBackend: () async {
          calls.add('startBackend');
          startEntered.complete();
          await allowStart.future;
          return true;
        },
      );

      final start = coordinator.startNode(reason: 'platform_start');
      await startEntered.future;
      final stood = coordinator.standDown(reason: 'identity_boundary');
      allowStart.complete();
      await start;
      await stood;

      // The stand-down is serialized behind the start, so the teardown runs
      // last and the runtime ends down.
      expect(calls.last, 'cancelWatchdog');
      expect(calls, contains('stopBackend'));
      expect(coordinator.hasAccount, isFalse);
      expect(coordinator.intent, PlatformNodeIntent.unset);
    });

    test('terminal reset closes admission synchronously without graceful stop',
        () {
      final coordinator = build(android: true);

      coordinator.closeForTerminalReset();

      expect(calls, ['retireProducerLeases', 'disableRecovery']);
      expect(coordinator.acceptingRuntimeWork, isFalse);
      expect(coordinator.hasAccount, isFalse);
      expect(coordinator.intent, PlatformNodeIntent.unset);
    });

    test('terminal reset admission never reopens in this process', () async {
      final coordinator = build(android: true);
      coordinator.closeForTerminalReset();
      calls.clear();

      expect(await coordinator.startNode(reason: 'stale_bridge'), isFalse);
      await coordinator.stopNode(reason: 'stale_stop');
      expect(
        await coordinator.reportColdBoot(hasAccount: true),
        isFalse,
      );
      expect(calls, isEmpty);
    });

    test('terminal reset supersedes an in-flight start before recovery wiring',
        () async {
      final startEntered = Completer<void>();
      final allowStart = Completer<void>();
      final coordinator = build(
        android: true,
        startBackend: () async {
          calls.add('startBackend');
          startEntered.complete();
          await allowStart.future;
          return true;
        },
      );

      final start = coordinator.startNode(reason: 'platform_start');
      await startEntered.future;
      coordinator.closeForTerminalReset();
      allowStart.complete();

      await start;

      expect(calls, [
        'startBackend',
        'retireProducerLeases',
        'disableRecovery',
      ]);
    });
  });
}
