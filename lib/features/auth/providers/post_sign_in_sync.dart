import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/onboarding/data/wallet_provisioning_api.dart';
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

class AccountReconciliationFailure {
  const AccountReconciliationFailure({required this.message, this.code});

  final String message;
  final String? code;
}

final accountReconciliationFailureProvider =
    StateProvider<AccountReconciliationFailure?>((ref) => null);

bool _isTransientReconcileFailure(Object error) {
  if (error is StaleAuthCredentialException ||
      error is AuthTokenUnavailableException ||
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return true;
  }
  if (error is WalletProvisioningException) {
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
///   fresh sign-ins and boot restores of an interrupted reconcile — every
///   path that publishes a reconciling identity.
/// - transition into [IdentityPhase.ready] → retry any pending zkPassport
///   backend completion (the identity-keyed outbox row). Runs only once the
///   identity is settled so a proof is never submitted under an unsettled
///   bucket/token pairing.
///
/// Node lifecycle is platform-controlled (thin-shell migration): SV chrome
/// requests start/stop over bridge v4 once the identity settles. The driver
/// does not start the node itself. Guest-node admission is currently disabled;
/// its keyless construction support remains dormant for a future explicit
/// product mode.
///
/// Failures are logged and reported, never rethrown: this is opportunistic
/// repair, and each unit has its own recovery path (the persisted
/// reconciling phase re-runs on next boot, cold-start ZK retry).
class IdentityDriver {
  IdentityDriver({
    required Future<void> Function() reconcileNodeAccount,
    required Future<void> Function() retryPendingZkCompletion,
    Future<bool> Function()? refreshAccountAuthority,
    void Function(AccountReconciliationStatus)? publishStatus,
    void Function(AccountReconciliationFailure?)? publishFailure,
    Timer Function(Duration, void Function())? createRetryTimer,
    this.maxReconcileAttempts = 4,
    this.refreshTtl = const Duration(minutes: 15),
  })  : _reconcileNodeAccount = reconcileNodeAccount,
        _retryPendingZkCompletion = retryPendingZkCompletion,
        _refreshAccountAuthority =
            refreshAccountAuthority ?? (() async => true),
        _publishStatus = publishStatus ?? ((_) {}),
        _publishFailure = publishFailure ?? ((_) {}),
        _createRetryTimer = createRetryTimer ?? _defaultRetryTimer;

  final Future<void> Function() _reconcileNodeAccount;
  final Future<void> Function() _retryPendingZkCompletion;
  final Future<bool> Function() _refreshAccountAuthority;
  final void Function(AccountReconciliationStatus) _publishStatus;
  final void Function(AccountReconciliationFailure?) _publishFailure;
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
      // The request itself is not cancellable. Exact identity checks discard
      // its result; release this coalescing slot so a new identity cannot join
      // it.
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
      _publishFailure(null);
      lastRun = _onReady(next);
      unawaited(lastRun);
      return;
    }
    if (next.phase != IdentityPhase.ready) {
      _publishFailure(null);
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
    _publishFailure(null);
    try {
      await _reconcileNodeAccount();
    } catch (error, stackTrace) {
      if (!_isReconciling(epoch)) return;
      final retry = _isTransientReconcileFailure(error) &&
          _reconcileAttempt < maxReconcileAttempts;
      if (!retry) {
        _publishStatus(AccountReconciliationStatus.failed);
        _publishFailure(
          AccountReconciliationFailure(
            message: error is LeaderboardApiException
                ? error.message
                : 'Could not prepare the signed-in account.',
            code: error is LeaderboardApiException ? error.code : null,
          ),
        );
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

  /// Restarts a failed reconciling identity and waits until that attempt has
  /// either committed the ready identity or failed again. Used after a
  /// verified legacy-wallet claim so proof creation can continue in-place.
  Future<bool> retryReconciliation() async {
    if (_disposed) return false;
    if (_latestIdentity.phase == IdentityPhase.ready) return true;
    if (_latestIdentity.phase != IdentityPhase.reconciling) return false;

    _cancelRetry();
    final existingRun = _reconcileRun;
    if (existingRun != null) await existingRun;
    if (_latestIdentity.phase == IdentityPhase.ready) return true;
    if (_latestIdentity.phase != IdentityPhase.reconciling || _disposed) {
      return false;
    }

    _startReconcile(resetAttempts: true);
    final retryRun = _reconcileRun;
    if (retryRun != null) await retryRun;
    return !_disposed && _latestIdentity.phase == IdentityPhase.ready;
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
      final refreshed = await _refreshAccountAuthority();
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
    refreshAccountAuthority: () =>
        ref.read(nodeAccountReconcilerProvider).refreshAccountAuthority(),
    retryPendingZkCompletion: () =>
        ref.read(zkPassportPipelineProvider.notifier).retryPendingCompletion(),
    publishStatus: (status) =>
        ref.read(accountReconciliationStatusProvider.notifier).state = status,
    publishFailure: (failure) =>
        ref.read(accountReconciliationFailureProvider.notifier).state = failure,
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
