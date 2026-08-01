import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';

Identity _identity(IdentityPhase phase, {int epoch = 1}) =>
    Identity(epoch: epoch, phase: phase);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdentityDriver', () {
    test('a reconciling identity triggers the account reconcile', () async {
      final calls = <String>[];
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
      );

      // Covers sign-in, boot restore of an interrupted reconcile, and season
      // rollover uniformly: each publishes a reconciling identity.
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

    test('becoming guest starts keyless node syncing when wired', () async {
      final calls = <String>[];
      final guest = _identity(IdentityPhase.guest, epoch: 2);
      final driver = IdentityDriver(
        reconcileNodeAccount: () async => calls.add('reconcile'),
        retryPendingZkCompletion: () async => calls.add('zk-retry'),
        startGuestNode: (identity) async {
          expect(identity, same(guest));
          calls.add('guest-node');
        },
      );

      driver.onIdentityChanged(
        _identity(IdentityPhase.transitioning, epoch: 2),
        guest,
      );
      await driver.lastRun;

      expect(calls, ['guest-node']);
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
  });

  group('activeSeasonIdOf', () {
    SeasonDto season(int id, {required bool active}) => SeasonDto(
          id: id,
          name: 'Season $id',
          isActive: active,
        );

    test('returns the active season id', () {
      expect(
        activeSeasonIdOf([season(4, active: false), season(5, active: true)]),
        5,
      );
    });

    test('returns null when no season is active', () {
      // Old seasons normally remain in the response; the ACTIVE flag is the
      // authoritative signal, never list membership or the UI-selected
      // reporting season.
      expect(activeSeasonIdOf([season(4, active: false)]), isNull);
    });

    test('returns null while unknown', () {
      expect(activeSeasonIdOf(null), isNull);
    });
  });
}
