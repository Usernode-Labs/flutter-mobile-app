import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';

Identity _identity(IdentityPhase phase, {int epoch = 1}) =>
    Identity(epoch: epoch, phase: phase);

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdentityDriver', () {
    test('a reconciling identity triggers the account reconcile', () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      // Covers sign-in and boot restore of an interrupted reconcile: each
      // publishes a reconciling identity.
      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated),
        _identity(IdentityPhase.reconciling, epoch: 2),
      );
      await driver.lastRun;

      expect(calls, ['reconcile']);
    });

    test('becoming ready triggers the pending zk completion retry', () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      // The reconcile commit publishes ready; the proof preserved across a
      // 401 (or an interrupted send) must be retried NOW under the settled
      // identity, not on the next cold start.
      driver.onIdentityChanged(
        _identity(IdentityPhase.reconciling),
        _identity(IdentityPhase.ready),
      );
      await driver.lastRun;

      expect(calls, ['zk-retry']);
    });

    test('a boot that restores directly to ready also retries zk', () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.unknown),
        _identity(IdentityPhase.ready),
      );
      await driver.lastRun;

      expect(calls, ['zk-retry']);
    });

    test('ready -> ready republications do not re-trigger the retry', () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.ready),
        _identity(IdentityPhase.ready),
      );
      expect(driver.lastRun, isNull);
      expect(calls, isEmpty);
    });

    test('becoming guest runs nothing (node lifecycle is platform-owned)',
        () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.transitioning, epoch: 2),
        _identity(IdentityPhase.guest, epoch: 2),
      );
      expect(driver.lastRun, isNull);
      expect(calls, isEmpty);
    });

    test('signed-out transitions run nothing', () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.ready),
        _identity(IdentityPhase.unauthenticated, epoch: 2),
      );
      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated, epoch: 2),
        _identity(IdentityPhase.guest, epoch: 3),
      );
      expect(driver.lastRun, isNull);
      expect(calls, isEmpty);
    });

    test('a failing reconcile does not propagate', () async {
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => throw Exception('offline'),
        retryPendingZkCompletion: () async {},
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated),
        _identity(IdentityPhase.reconciling, epoch: 2),
      );
      // Must complete without throwing: the driver is opportunistic repair;
      // the persisted reconciling phase re-runs on the next boot.
      await driver.lastRun;
    });

    test('publishes the wallet recovery code and can retry through ready',
        () async {
      var reconcileCalls = 0;
      final failures = <AccountReconciliationFailure?>[];
      final reconciling = _identity(IdentityPhase.reconciling, epoch: 2);
      final ready = _identity(IdentityPhase.ready, epoch: 2);
      late IdentityDriver driver;
      driver = IdentityDriver(
        reconcileNodeAccount: () async {
          reconcileCalls++;
          if (reconcileCalls == 1) {
            throw LeaderboardApiException(
              409,
              'No on-chain accounts are available.',
              code: 'wallet_pool_exhausted',
            );
          }
          driver.onIdentityChanged(reconciling, ready);
        },
        retryPendingZkCompletion: () async {},
        publishFailure: failures.add,
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated),
        reconciling,
      );
      await driver.lastRun;

      expect(reconcileCalls, 1);
      expect(
        failures.whereType<AccountReconciliationFailure>().single.code,
        'wallet_pool_exhausted',
      );

      expect(await driver.retryReconciliation(), isTrue);
      expect(reconcileCalls, 2);
      expect(failures.last, isNull);
    });

    test('a failing zk retry does not propagate', () async {
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {},
        retryPendingZkCompletion: () async => throw Exception('still 401'),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.reconciling),
        _identity(IdentityPhase.ready),
      );
      await driver.lastRun;
    });

    test('transient reconciliation retries within the same epoch', () async {
      var calls = 0;
      late _ManualTimer retry;
      final statuses = <AccountReconciliationStatus>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {
          calls++;
          if (calls == 1) throw AccountApiException(0, 'offline');
        },
        retryPendingZkCompletion: () async {},
        publishStatus: statuses.add,
        createRetryTimer: (_, callback) => retry = _ManualTimer(callback),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated),
        _identity(IdentityPhase.reconciling, epoch: 2),
      );
      await driver.lastRun;
      expect(calls, 1);
      expect(statuses.last, AccountReconciliationStatus.transient);

      retry.fire();
      await Future<void>.delayed(Duration.zero);
      await driver.lastRun;
      expect(calls, 2);
    });

    test('temporarily unavailable secure storage schedules a retry', () async {
      var calls = 0;
      late _ManualTimer retry;
      final statuses = <AccountReconciliationStatus>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {
          calls++;
          if (calls == 1) throw const AuthTokenUnavailableException();
        },
        retryPendingZkCompletion: () async {},
        publishStatus: statuses.add,
        createRetryTimer: (_, callback) => retry = _ManualTimer(callback),
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated),
        _identity(IdentityPhase.reconciling, epoch: 2),
      );
      await driver.lastRun;
      expect(statuses.last, AccountReconciliationStatus.transient);

      retry.fire();
      await Future<void>.delayed(Duration.zero);
      await driver.lastRun;
      expect(calls, 2);
    });

    test('identity replacement cancels a scheduled retry', () async {
      var calls = 0;
      late _ManualTimer retry;
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {
          calls++;
          throw AccountApiException(0, 'offline');
        },
        retryPendingZkCompletion: () async {},
        createRetryTimer: (_, callback) => retry = _ManualTimer(callback),
      );

      final reconciling = _identity(IdentityPhase.reconciling, epoch: 2);
      driver.onIdentityChanged(
        _identity(IdentityPhase.unauthenticated),
        reconciling,
      );
      await driver.lastRun;
      expect(retry.isActive, isTrue);

      driver.onIdentityChanged(
        reconciling,
        _identity(IdentityPhase.transitioning, epoch: 3),
      );
      expect(retry.isActive, isFalse);
      retry.fire();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    });

    test('ready refreshes coalesce and transient failures retry', () async {
      var calls = 0;
      final first = Completer<bool>();
      late _ManualTimer retry;
      final statuses = <AccountReconciliationStatus>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {},
        retryPendingZkCompletion: () async {},
        refreshAccountAuthority: () async {
          calls++;
          if (calls == 1) return first.future;
          return true;
        },
        publishStatus: statuses.add,
        createRetryTimer: (_, callback) => retry = _ManualTimer(callback),
      );

      final ready = _identity(IdentityPhase.ready, epoch: 2);
      driver.onIdentityChanged(_identity(IdentityPhase.reconciling), ready);
      final duplicate = driver.refreshNow();
      expect(calls, 1);
      first.completeError(AccountApiException(0, 'offline'));
      await driver.lastRun;
      expect(await duplicate, isFalse);
      expect(statuses.last, AccountReconciliationStatus.transient);

      retry.fire();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(statuses.last, AccountReconciliationStatus.settled);
    });

    test('a delayed ready refresh cannot settle a replaced identity', () async {
      final refresh = Completer<bool>();
      final statuses = <AccountReconciliationStatus>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {},
        retryPendingZkCompletion: () async {},
        refreshAccountAuthority: () => refresh.future,
        publishStatus: statuses.add,
      );

      final ready = _identity(IdentityPhase.ready, epoch: 2);
      driver.onIdentityChanged(_identity(IdentityPhase.reconciling), ready);
      driver.onIdentityChanged(
        ready,
        _identity(IdentityPhase.transitioning, epoch: 3),
      );
      refresh.complete(true);
      await driver.lastRun;

      expect(statuses, isNot(contains(AccountReconciliationStatus.settled)));
    });

    test('a refresh-closing identity does not run the ready-only zk retry',
        () async {
      var zkRetries = 0;
      late IdentityDriver driver;
      final ready = _identity(IdentityPhase.ready, epoch: 2);
      driver = IdentityDriver(
        reconcileNodeAccount: () async {},
        retryPendingZkCompletion: () async => zkRetries++,
        refreshAccountAuthority: () async {
          driver.onIdentityChanged(
            ready,
            _identity(IdentityPhase.reconciling, epoch: 3),
          );
          return false;
        },
      );

      driver.onIdentityChanged(_identity(IdentityPhase.reconciling), ready);
      await driver.lastRun;

      expect(zkRetries, 0);
    });

    test('a new ready epoch does not join an obsolete refresh', () async {
      var calls = 0;
      final oldRefresh = Completer<bool>();
      final driver = IdentityDriver(
        reconcileNodeAccount: () async {},
        retryPendingZkCompletion: () async {},
        refreshAccountAuthority: () {
          calls++;
          return calls == 1 ? oldRefresh.future : Future.value(true);
        },
      );

      final oldReady = _identity(IdentityPhase.ready, epoch: 2);
      driver.onIdentityChanged(
        _identity(IdentityPhase.reconciling),
        oldReady,
      );
      final newReconciling = _identity(IdentityPhase.reconciling, epoch: 3);
      driver.onIdentityChanged(oldReady, newReconciling);
      driver.onIdentityChanged(
        newReconciling,
        _identity(IdentityPhase.ready, epoch: 3),
      );

      await driver.lastRun;
      expect(calls, 2);
      oldRefresh.complete(false);
      await Future<void>.delayed(Duration.zero);
    });
  });
}
