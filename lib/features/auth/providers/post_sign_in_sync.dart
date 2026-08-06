import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/seasons_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

final _log = LoggingService.instance.withTag('usernode/IdentityDriver');

enum AccountReconciliationStatus {
  idle,
  reconciling,
  transient,
  refreshing,
  settled,
  failed,
}

final accountReconciliationStatusProvider =
    StateProvider<AccountReconciliationStatus>(
  (ref) => AccountReconciliationStatus.idle,
);

bool _isTransientReconcileFailure(Object error) {
  if (error is StaleAuthCredentialException ||
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return true;
  }
  if (error is LeaderboardApiException) {
    return error.statusCode == 429 || error.statusCode >= 500;
  }
  if (error is AccountApiException) {
    return error.statusCode == 0 ||
        error.statusCode == 429 ||
        error.statusCode >= 500;
  }
  return false;
}

Timer _defaultRetryTimer(Duration duration, void Function() callback) =>
    Timer(duration, callback);

/// Drives the work each identity phase demands. The [SessionController] owns
/// WHAT the identity is; this driver owns making the app converge on it:
///
/// - [IdentityPhase.reconciling] → run the [NodeAccountReconciler]. Covers
///   fresh sign-ins, boot restores of an interrupted reconcile, and season
///   rollovers — every path that publishes a reconciling identity.
/// - transition into [IdentityPhase.ready] → retry any pending zkPassport
///   backend completion (the identity-keyed outbox row). Runs only once the
///   identity is settled so a proof is never submitted under an unsettled
///   bucket/token pairing.
///
/// Node lifecycle is platform-controlled (thin-shell migration): SV chrome
/// requests start/stop over bridge v4 once the identity settles. The driver
/// no longer starts the node itself — neither for guests (the guest keyless
/// start is gone) nor after reconcile.
///
/// Failures are logged and reported, never rethrown: this is opportunistic
/// repair, and each unit has its own recovery path (the persisted
/// reconciling phase re-runs on next boot, cold-start ZK retry).
class IdentityDriver {
  IdentityDriver({
    required Future<void> Function() reconcileNodeAccount,
    required Future<void> Function() retryPendingZkCompletion,
    Future<bool> Function()? refreshAuthoritativeState,
    void Function(AccountReconciliationStatus)? publishStatus,
    Timer Function(Duration, void Function())? createRetryTimer,
    this.maxReconcileAttempts = 4,
    this.refreshTtl = const Duration(minutes: 15),
  })  : _reconcileNodeAccount = reconcileNodeAccount,
        _retryPendingZkCompletion = retryPendingZkCompletion,
        _refreshAuthoritativeState =
            refreshAuthoritativeState ?? (() async => true),
        _publishStatus = publishStatus ?? ((_) {}),
        _createRetryTimer = createRetryTimer ?? _defaultRetryTimer;

  final Future<void> Function() _reconcileNodeAccount;
  final Future<void> Function() _retryPendingZkCompletion;
  final Future<bool> Function() _refreshAuthoritativeState;
  final void Function(AccountReconciliationStatus) _publishStatus;
  final Timer Function(Duration, void Function()) _createRetryTimer;
  final int maxReconcileAttempts;
  final Duration refreshTtl;

  Identity _latestIdentity = const Identity.unknown();
  Future<void>? _reconcileRun;
  Future<bool>? _refreshRun;
  Identity? _refreshIdentity;
  Timer? _retryTimer;
  int _reconcileEpoch = -1;
  int _reconcileAttempt = 0;
  int _refreshAttempt = 0;
  DateTime? _lastRefreshAt;
  int? _lastRefreshEpoch;
  bool _disposed = false;

  /// The run started by the most recent identity change, for tests and
  /// callers that need to observe completion. Null until the first trigger.
  Future<void>? lastRun;

  void onIdentityChanged(Identity? previous, Identity next) {
    _latestIdentity = next;
    final refreshIdentity = _refreshIdentity;
    if (refreshIdentity != null && !next.sameScopeAs(refreshIdentity)) {
      // Do not cancel the old request; the reconciler drains/serializes it.
      // Only release this coalescing slot so a new epoch cannot join it.
      _refreshRun = null;
      _refreshIdentity = null;
    }
    if (_reconcileEpoch != next.epoch ||
        next.phase != IdentityPhase.reconciling) {
      _cancelRetry();
    }
    if (_lastRefreshEpoch != null && _lastRefreshEpoch != next.epoch) {
      _lastRefreshAt = null;
      _lastRefreshEpoch = null;
    }

    if (next.phase == IdentityPhase.reconciling) {
      if (_reconcileEpoch != next.epoch) {
        _reconcileEpoch = next.epoch;
        _reconcileAttempt = 0;
      }
      _startReconcile();
      return;
    }
    final becameReady = next.phase == IdentityPhase.ready &&
        previous?.phase != IdentityPhase.ready;
    if (becameReady) {
      lastRun = _onReady(next);
      unawaited(lastRun);
      return;
    }
    if (next.phase != IdentityPhase.ready) {
      _publishStatus(AccountReconciliationStatus.idle);
    }
  }

  bool _isReconciling(int epoch) =>
      !_disposed &&
      _latestIdentity.epoch == epoch &&
      _latestIdentity.phase == IdentityPhase.reconciling;

  bool _isReady(Identity expected) =>
      !_disposed &&
      _latestIdentity.phase == IdentityPhase.ready &&
      _latestIdentity.sameScopeAs(expected);

  void _startReconcile({bool resetAttempts = false}) {
    if (_disposed || _reconcileRun != null || _retryTimer != null) return;
    if (resetAttempts) _reconcileAttempt = 0;
    final epoch = _latestIdentity.epoch;
    if (!_isReconciling(epoch)) return;
    _reconcileAttempt++;
    late Future<void> run;
    run = _runReconcile(epoch).whenComplete(() {
      if (!identical(_reconcileRun, run)) return;
      _reconcileRun = null;
      if (_latestIdentity.epoch != epoch &&
          _latestIdentity.phase == IdentityPhase.reconciling) {
        _startReconcile();
      }
    });
    _reconcileRun = run;
    lastRun = run;
    unawaited(run);
  }

  Future<void> _runReconcile(int epoch) async {
    _publishStatus(AccountReconciliationStatus.reconciling);
    try {
      await _reconcileNodeAccount();
    } catch (error, stackTrace) {
      if (!_isReconciling(epoch)) return;
      final retry = _isTransientReconcileFailure(error) &&
          _reconcileAttempt < maxReconcileAttempts;
      if (!retry) {
        _publishStatus(AccountReconciliationStatus.failed);
        await SentryUtil.captureError(
          error,
          stackTrace,
          tag: 'identity_reconcile',
        );
        return;
      }

      final delay = Duration(seconds: 1 << (_reconcileAttempt - 1));
      _publishStatus(AccountReconciliationStatus.transient);
      _retryTimer = _createRetryTimer(delay, () {
        _retryTimer = null;
        if (_isReconciling(epoch)) _startReconcile();
      });
    }
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Refreshes ready-identity authority after lifecycle/network/timer events.
  /// Concurrent triggers coalesce in [NodeAccountReconciler].
  Future<bool> refreshNow() {
    final expected = _latestIdentity;
    if (expected.phase == IdentityPhase.reconciling) {
      if (_retryTimer != null) {
        _cancelRetry();
        _startReconcile();
      } else if (_reconcileRun == null) {
        _startReconcile(resetAttempts: true);
      }
      return Future.value(false);
    }
    if (expected.phase != IdentityPhase.ready || _disposed) {
      return Future.value(false);
    }
    return _startRefresh(expected, resetAttempts: true);
  }

  /// Returns true only when node start can use recently refreshed authority.
  Future<bool> ensureFreshBeforeNodeStart() {
    final expected = _latestIdentity;
    if (expected.phase != IdentityPhase.ready || _disposed) {
      return Future.value(false);
    }
    final refreshedAt = _lastRefreshAt;
    if (_lastRefreshEpoch == expected.epoch &&
        refreshedAt != null &&
        DateTime.now().difference(refreshedAt) < refreshTtl) {
      return Future.value(true);
    }
    return _startRefresh(expected, resetAttempts: true);
  }

  Future<bool> _startRefresh(
    Identity expected, {
    bool resetAttempts = false,
  }) {
    final inFlight = _refreshRun;
    if (inFlight != null && _refreshIdentity?.sameScopeAs(expected) == true) {
      return inFlight;
    }
    if (resetAttempts) _refreshAttempt = 0;
    _cancelRetry();
    _refreshAttempt++;
    late Future<bool> run;
    run = _refreshReady(expected).whenComplete(() {
      if (identical(_refreshRun, run)) {
        _refreshRun = null;
        _refreshIdentity = null;
      }
    });
    _refreshRun = run;
    _refreshIdentity = expected;
    return run;
  }

  Future<bool> _refreshReady(Identity expected) async {
    _publishStatus(AccountReconciliationStatus.refreshing);
    try {
      final refreshed = await _refreshAuthoritativeState();
      if (!refreshed || !_isReady(expected)) return false;
      _refreshAttempt = 0;
      _lastRefreshAt = DateTime.now();
      _lastRefreshEpoch = expected.epoch;
      _publishStatus(AccountReconciliationStatus.settled);
      return true;
    } catch (error, stackTrace) {
      if (!_isReady(expected)) return false;
      _log.warn('Account authority refresh failed: $error');
      if (_isTransientReconcileFailure(error) &&
          _refreshAttempt < maxReconcileAttempts) {
        final delay = Duration(seconds: 1 << (_refreshAttempt - 1));
        _publishStatus(AccountReconciliationStatus.transient);
        _retryTimer = _createRetryTimer(delay, () {
          _retryTimer = null;
          if (_isReady(expected)) unawaited(_startRefresh(expected));
        });
      } else {
        _publishStatus(AccountReconciliationStatus.failed);
        await SentryUtil.captureError(
          error,
          stackTrace,
          tag: 'identity_refresh',
        );
      }
      return false;
    }
  }

  Future<void> _onReady(Identity expected) async {
    await refreshNow();
    if (!_isReady(expected)) return;
    await _runZkRetry();
  }

  Future<void> _runZkRetry() async {
    try {
      await _retryPendingZkCompletion();
    } catch (e, st) {
      _log.warn('Pending zk completion retry failed: $e');
      await SentryUtil.captureError(e, st, tag: 'identity_zk_retry');
    }
  }

  void dispose() {
    _disposed = true;
    _cancelRetry();
  }
}

/// Always-alive listener wiring [IdentityDriver] to [identityProvider].
/// Read once from the app root (like `backendLifecycleProvider`) so the
/// listener exists for the whole app lifetime.
final identityDriverProvider = Provider<IdentityDriver>((ref) {
  final driver = IdentityDriver(
    reconcileNodeAccount: () async {
      await ref.read(nodeAccountReconcilerProvider).reconcile();
    },
    refreshAuthoritativeState: () =>
        ref.read(nodeAccountReconcilerProvider).refreshAuthoritativeState(),
    retryPendingZkCompletion: () =>
        ref.read(zkPassportPipelineProvider.notifier).retryPendingCompletion(),
    publishStatus: (status) =>
        ref.read(accountReconciliationStatusProvider.notifier).state = status,
  );
  ref.listen<Identity>(
    identityProvider,
    driver.onIdentityChanged,
    fireImmediately: true,
  );
  final refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
    unawaited(driver.refreshNow());
  });
  final connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .where((results) => results.any((r) => r != ConnectivityResult.none))
      .listen((_) => unawaited(driver.refreshNow()));
  ref.onDispose(() {
    refreshTimer.cancel();
    unawaited(connectivitySubscription.cancel());
    driver.dispose();
  });
  return driver;
});

/// The backend's ACTIVE season id from the authoritative `/seasons` response
/// — NOT the user-selected reporting season (`seasonEventContextProvider`,
/// which the season picker mutates and bootstrap restores from cache).
/// Null while unknown (loading, unauthenticated, or no active season).
int? activeSeasonIdOf(List<SeasonDto>? seasons) {
  if (seasons == null) return null;
  for (final season in seasons) {
    if (season.isActive) return season.id;
  }
  return null;
}

/// Always-alive listener that hands the authoritative active season to the
/// [SessionController]. `/wallet/provision` allocates per season: a user who
/// stays signed in across a rollover would otherwise keep the previous
/// season's wallet (and be stuck on stale-registration) until they logged
/// out and back in — no sign-in transition ever fires for them.
///
/// The controller compares the reported season against the identity's
/// provisioned season (persisted at reconcile commit) and re-enters the
/// reconciling phase only on a genuine mismatch, so this can safely fire on
/// every `/seasons` refresh.
final seasonRolloverSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<SeasonDto>?>>(seasonsProvider, (previous, next) {
    final activeSeasonId = activeSeasonIdOf(next.valueOrNull);
    if (activeSeasonId == null) return;
    final expectedIdentity = ref.read(identityProvider);
    unawaited(
      ref.read(identityProvider.notifier).beginSeasonRollover(
            activeSeasonId: activeSeasonId,
            expectedIdentity: expectedIdentity,
          ),
    );
  });
});
