import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/session_runtime_boundary.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/SessionController');

/// Work was submitted to a controller whose runtime has been replaced.
class SessionControllerRetiredException implements Exception {
  const SessionControllerRetiredException();

  @override
  String toString() => 'SessionControllerRetiredException()';
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider = Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

/// The single source of truth for the app's current [Identity].
///
/// All identity transitions go through [SessionController]; everything else
/// only reads. Watch this (or a `select` on it) from any provider whose
/// output depends on WHO the user is — auth status, account bucket,
/// participant id, or season binding.
final identityProvider = StateNotifierProvider<SessionController, Identity>(
  (ref) {
    final controller = SessionController(
      tokenStore: ref.watch(authTokenStoreProvider),
      guestFlag: ref.watch(authGuestFlagProvider),
      repository: ref.watch(authRepositoryProvider),
    );
    unawaited(controller.restore());
    return controller;
  },
);

/// The one state machine that owns identity transitions.
///
/// Design rules (see docs/identity-lifecycle-invariants.md):
///
/// - **Serialized**: every transition runs on an internal queue, so two
///   transitions can never interleave their persistence writes.
/// - **Single writer**: this class is the only writer of the ambient
///   [IdentitySnapshots] mirror and of [NetworkPrefs.setActiveBucket]
///   (enforced by ds_lints).
/// - **Epoch-scoped effects**: results of async work started under an older
///   epoch ([reconcileSucceeded], [onUnauthorized]) are ignored.
/// - **Crash-safe login**: the reconcile-pending marker and the staged
///   participant id are persisted BEFORE the session token becomes
///   boot-restorable, so an interrupted login is always repaired on the next
///   boot ([restore] routes it back into [IdentityPhase.reconciling]).
class SessionController extends StateNotifier<Identity> {
  SessionController({
    required AuthTokenStore tokenStore,
    required AuthGuestFlag guestFlag,
    required AuthRepository repository,
    Future<void> Function()? suspendNode,
    Future<void> Function()? hardStopRuntime,
    SessionRuntimeBoundary? runtimeBoundary,
  })  : _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _repository = repository,
        _suspendNode = suspendNode ?? _defaultSuspendNode,
        _hardStopRuntime =
            hardStopRuntime ?? suspendNode ?? _defaultHardStopRuntime,
        _runtimeBoundary = runtimeBoundary ?? SessionRuntimeBoundary.instance,
        super(Identity.unknown(epoch: IdentitySnapshots.current.epoch)) {
    IdentitySnapshots.publish(state);
  }

  static const _kReconcilePendingKeyBase = 'account:reconcile_pending';
  static const _kProvisionedSeasonKeyBase = 'identity:provisioned_season';
  static const _kLifecycleOwnershipConfirmedKeyBase =
      'identity:lifecycle_ownership_confirmed';
  static const _kSeasonBaselineMigratedKeyBase =
      'identity:season_baseline_migrated';

  final AuthTokenStore _tokenStore;
  final AuthGuestFlag _guestFlag;
  final AuthRepository _repository;
  final SessionRuntimeBoundary _runtimeBoundary;

  /// Stops a running node when a transition makes account ownership unknown.
  /// Injectable for tests; the default touches the Rust backend (a no-op
  /// when the node was never started).
  final Future<void> Function() _suspendNode;
  final Future<void> Function() _hardStopRuntime;

  static Future<void> _defaultSuspendNode() =>
      RustBackendService.instance.stopNode();

  static Future<void> _defaultHardStopRuntime() =>
      NodeLifecycleCoordinator.instance.hardStopForSessionBoundary(
        reason: 'session_identity_boundary',
      );

  Future<void>? _restoreFuture;
  Future<void> _queueTail = Future.value();
  final Queue<Future<void> Function()> _pendingTransitions = Queue();
  bool _transitionActive = false;
  bool _retired = false;

  /// Completes when every transition queued so far has finished its
  /// persistence writes. Gate-closing transitions publish the new identity
  /// BEFORE they persist (so concurrent node starts / signing see the closed
  /// gate immediately); work triggered by that publish which needs the
  /// persisted side (e.g. the reconciler's authenticated provision call
  /// reading the just-written session token) awaits this first.
  Future<void> get transitionsSettled => _queueTail;

  /// Stops this runtime from accepting new identity work. The hard transition
  /// that retired it is already active and is allowed to finish persistence.
  void retireForRuntimeRestart() => _retired = true;

  /// Runs [body] after every previously queued transition has finished, so
  /// transitions never interleave. When idle, [body] starts synchronously so
  /// gate-closing publications happen before this method returns its Future.
  Future<T> _transition<T>(
    Future<T> Function() body, {
    T Function()? whenRetired,
  }) {
    Future<T> retiredResult() {
      if (whenRetired != null) return Future<T>.value(whenRetired());
      return Future<T>.error(const SessionControllerRetiredException());
    }

    if (_retired || !mounted) return retiredResult();
    final result = Completer<T>();

    Future<void> run() async {
      try {
        if (_retired || !mounted) {
          if (whenRetired != null) {
            result.complete(whenRetired());
          } else {
            result.completeError(const SessionControllerRetiredException());
          }
        } else {
          result.complete(await body());
        }
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        if (_pendingTransitions.isEmpty) {
          _transitionActive = false;
        } else {
          unawaited(_pendingTransitions.removeFirst()());
        }
      }
    }

    _queueTail = result.future.then<void>((_) {}, onError: (_) {});
    if (_transitionActive) {
      _pendingTransitions.add(run);
    } else {
      _transitionActive = true;
      unawaited(run());
    }
    return result.future;
  }

  void _publish(Identity next) {
    IdentitySnapshots.publish(next);
    NetworkPrefs.setActiveBucket(
      next.address,
      guest: next.address == null,
    );
    if (mounted) state = next;
  }

  // -- persistence owned by the controller -----------------------------------

  String get _reconcileMarkerKey =>
      NetworkPrefs.prefixKey(_kReconcilePendingKeyBase);

  Future<void> _writeReconcileMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reconcileMarkerKey, true);
  }

  Future<bool> _readReconcileMarker() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reconcileMarkerKey) ?? false;
  }

  Future<void> _clearReconcileMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reconcileMarkerKey);
  }

  Future<void> _writeProvisionedSeason(String bucket, int? seasonId) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        NetworkPrefs.prefixAccountKeyFor(_kProvisionedSeasonKeyBase, bucket);
    if (seasonId == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, seasonId);
    }
  }

  Future<int?> _readProvisionedSeason(String bucket) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(
        NetworkPrefs.prefixAccountKeyFor(_kProvisionedSeasonKeyBase, bucket));
  }

  /// Whether this account bucket completed a reconcile under the lifecycle
  /// protocol owned by this controller. Legacy installs can have both a token
  /// and an account-bucket participant id without any durable proof that the
  /// token owns that account, so they must provision once before boot may
  /// restore directly to [IdentityPhase.ready].
  Future<bool> _readLifecycleOwnershipConfirmed(String bucket) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(NetworkPrefs.prefixAccountKeyFor(
            _kLifecycleOwnershipConfirmedKeyBase, bucket)) ??
        false;
  }

  Future<void> _writeLifecycleOwnershipConfirmed(String bucket) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      NetworkPrefs.prefixAccountKeyFor(
          _kLifecycleOwnershipConfirmedKeyBase, bucket),
      true,
    );
  }

  /// One-shot flag for the null-baseline migration in [beginSeasonRollover]:
  /// set before the migration reconcile is published so the migration can
  /// never loop if the backend does not return a season id.
  Future<bool> _readSeasonBaselineMigrated(String bucket) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(NetworkPrefs.prefixAccountKeyFor(
            _kSeasonBaselineMigratedKeyBase, bucket)) ??
        false;
  }

  Future<void> _writeSeasonBaselineMigrated(String bucket) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        NetworkPrefs.prefixAccountKeyFor(
            _kSeasonBaselineMigratedKeyBase, bucket),
        true);
  }

  // -- transitions ------------------------------------------------------------

  /// Resolve the boot identity. Idempotent: concurrent/repeated calls share
  /// one run. Network-free — a settled previous session restores directly to
  /// [IdentityPhase.ready]; only an interrupted login (persisted reconcile
  /// marker) or an account/bucket mismatch routes through
  /// [IdentityPhase.reconciling].
  Future<void> restore() => _restoreFuture ??= _transition(() async {
        final token = await _tokenStore.read();
        if (token != null && token.isNotEmpty) {
          await _restoreAuthenticated();
          return;
        }
        final guest = await _guestFlag.isGuest();
        if (guest) {
          _publish(Identity(
            epoch: state.epoch + 1,
            phase: IdentityPhase.guest,
          ));
          return;
        }
        // No session: local-only mode. The bucket follows the active local
        // account (its owner is offline-irrelevant — no token can act as
        // anyone), matching pre-auth behavior.
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));
      });

  Future<void> _restoreAuthenticated() async {
    final pendingMarker = await _readReconcileMarker();
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();

    if (!pendingMarker && active != null) {
      final bucket = NetworkPrefs.bucketForAddress(active.address);
      final ownerId = await loadParticipantIdInBucket(bucket);
      final lifecycleOwnershipConfirmed =
          await _readLifecycleOwnershipConfirmed(bucket);
      if (ownerId != null && lifecycleOwnershipConfirmed) {
        // The last reconcile completed under this lifecycle protocol (every
        // login sets the marker, and only a confirmed reconcile clears it and
        // records lifecycle ownership for the bucket).
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.ready,
          participantId: ownerId,
          accountId: active.id,
          address: active.address,
          provisionedSeasonId: await _readProvisionedSeason(bucket),
        ));
        return;
      }
    }

    // Interrupted login, fresh install with a restored token, or an account
    // whose ownership was never confirmed: reconcile before trusting any
    // account-scoped state. A guest-bucket participant id is authenticated
    // recovery state only when it was persisted together with an existing
    // pending marker. On the legacy/no-proof path it may be unrelated residue:
    // remove it BEFORE creating the marker (a crash in the opposite order
    // would make the residue look trusted on the next boot), then let the
    // reconciler recover the current token's user from `/me`.
    int? staged;
    if (pendingMarker) {
      staged = await loadParticipantIdInBucket(NetworkPrefs.guestBucket);
    } else {
      await clearGuestParticipantId();
      await _writeReconcileMarker();
    }
    _log.info('Boot restore requires account reconcile', context: {
      'hadMarker': pendingMarker,
      'hasActiveAccount': active != null,
      'hasStagedParticipantId': staged != null,
      'legacyOwnershipMigration': !pendingMarker && active != null,
    });
    _publish(Identity(
      epoch: state.epoch + 1,
      phase: IdentityPhase.reconciling,
      participantId: staged,
    ));
  }

  /// Accepts an authoritative authenticated session.
  ///
  /// A renewed credential for the current participant is rotated in place:
  /// the identity epoch, account binding, node, and surrounding runtime stay
  /// untouched. An initial login reconciles in the initiating runtime so a
  /// WebView can await and answer its handoff request. Replacing one
  /// authenticated participant with another crosses the process-level hard
  /// boundary before the new durable session target is written.
  Future<bool> completeLogin(
    AuthSession session, {
    Identity? expectedIdentity,
  }) =>
      _transition(() async {
        // The web handoff may wait for JavaScript acknowledgement before it
        // reaches this queue. It is authoritative only for the exact identity
        // scope that initiated that acknowledgement.
        if (expectedIdentity != null && !state.sameScopeAs(expectedIdentity)) {
          return false;
        }

        final participantId = session.participant.id;
        final current = state;

        if (current.isAuthenticated && current.participantId == participantId) {
          // Keep the same epoch: leases carrying the previous token are still
          // rejected by their exact-token check, while unrelated state does
          // not rebuild merely because the bearer was renewed.
          final replacedToken = await _tokenStore.read();
          await _tokenStore.write(session.token);
          if (replacedToken != null &&
              replacedToken.isNotEmpty &&
              replacedToken != session.token) {
            await _logoutBestEffort(replacedToken);
          }
          return true;
        }

        final replacingParticipant = current.isAuthenticated;
        final epoch = current.epoch + 1;
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));

        if (!replacingParticipant) {
          // No authenticated runtime is being displaced. Keep the initiating
          // interactive shell alive so it can finish the login handshake.
          await _persistLoginTarget(session);
          await _suspendNode();
          _publish(Identity(
            epoch: epoch,
            phase: IdentityPhase.reconciling,
            participantId: participantId,
          ));
          return true;
        }

        final replacedToken = await _tokenStore.read();
        // Remove the old boot target before tearing its runtime down. The new
        // credential is written only after cleanup has completed.
        await _tokenStore.clear();
        return _runtimeBoundary.replace<bool>(
          change: SessionRuntimeChange.participantReplacement,
          transition: (replacingRuntime) async {
            if (!replacingRuntime) await _hardStopRuntime();

            await _logoutBestEffort(replacedToken);
            await _persistLoginTarget(session, clearTokenFirst: false);

            if (!replacingRuntime) {
              _publish(Identity(
                epoch: epoch,
                phase: IdentityPhase.reconciling,
                participantId: participantId,
              ));
            }
            return true;
          },
        );
      }, whenRetired: () => false);

  Future<void> _persistLoginTarget(
    AuthSession session, {
    bool clearTokenFirst = true,
  }) async {
    if (clearTokenFirst) await _tokenStore.clear();
    // Marker + staged id BEFORE the token write are the crash-recovery
    // payload. A boot-restorable token therefore always restores through the
    // authoritative account reconcile until ownership is committed.
    await _writeReconcileMarker();
    await stageParticipantIdInGuestBucket(session.participant.id);
    await _guestFlag.clear();
    await _tokenStore.write(session.token);
  }

  Future<void> continueAsGuest() => _transition(() async {
        final epoch = state.epoch + 1;
        // Close signing/node gates before waiting for the existing producer to
        // stop. Publishing guest first would allow a new guest node start to
        // race the shutdown of the previous account's runtime.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));
        // Persist the guest choice before the fallible shutdown. If shutdown
        // fails, this isolate stays fail-closed in `transitioning`, while a
        // restart still restores guest instead of the previous credential.
        await _tokenStore.clear();
        await _guestFlag.setGuest();
        // A leftover staged id (interrupted earlier login) must not resolve
        // for an explicit guest session.
        await clearGuestParticipantId();
        await _clearReconcileMarker();
        await _suspendNode();
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.guest,
        ));
      });

  Future<bool> logout({Identity? expectedIdentity}) =>
      _logout(expectedIdentity: expectedIdentity);

  Future<bool> _logout({
    Identity? expectedIdentity,
    String? expectedToken,
    bool requireMissingToken = false,
  }) =>
      _transition(() async {
        // Async bridge callbacks may have been authorized by a prior identity.
        if (expectedIdentity != null && !state.sameScopeAs(expectedIdentity)) {
          return false;
        }

        String? token;
        if (expectedToken != null || requireMissingToken) {
          token = await _tokenStore.read();
          if (expectedIdentity != null &&
              !state.sameScopeAs(expectedIdentity)) {
            return false;
          }
          if (expectedToken != null && token != expectedToken) return false;
          if (requireMissingToken && token != null && token.isNotEmpty) {
            return false;
          }
        }

        final epoch = state.epoch + 1;
        // Revoke every in-memory account-sensitive lease before scheduling
        // the process-level boundary.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));
        token ??= await _tokenStore.read();

        // Make logout durable before cleanup. If the process dies while the
        // old runtime is stopping, the next launch still restores signed out.
        await _tokenStore.clear();
        await _guestFlag.clear();
        await clearGuestParticipantId();
        await _clearReconcileMarker();

        return _runtimeBoundary.replace<bool>(
          change: SessionRuntimeChange.logout,
          transition: (replacingRuntime) async {
            if (!replacingRuntime) {
              await _hardStopRuntime();
              final active =
                  await (await AccountsRepository.create()).getActive();
              _publish(Identity(
                epoch: epoch,
                phase: IdentityPhase.unauthenticated,
                accountId: active?.id,
                address: active?.address,
              ));
            }

            await _logoutBestEffort(token);
            return true;
          },
        );
      }, whenRetired: () => false);

  Future<void> _logoutBestEffort(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _repository.logout(token);
    } catch (e) {
      _log.warn('Server-side logout failed (token cleared anyway): $e');
    }
  }

  /// A request carrying [credential] came back 401. It may invalidate only
  /// that exact identity epoch and token.
  Future<void> onUnauthorized({
    required AuthCredentialLease credential,
  }) async {
    if (_retired || !mounted || state.epoch != credential.epoch) return;
    final identity = state;

    // A stray auth-required request outside an authenticated identity
    // invalidates only that exact token; it is not a session replacement.
    if (!identity.isAuthenticated) {
      await _transition(() async {
        if (!state.sameScopeAs(identity)) return;
        final currentToken = await _tokenStore.read();
        if (!state.sameScopeAs(identity) || currentToken != credential.token) {
          return;
        }
        await _tokenStore.clear();
      }, whenRetired: () {});
      return;
    }

    final loggedOut = await _logout(
      expectedIdentity: identity,
      expectedToken: credential.token,
    );
    if (!loggedOut) {
      _log.warn('Ignoring 401 for a credential that is no longer current');
    }
  }

  /// Repairs an authenticated identity whose credential disappeared before a
  /// request could be sent. A token written since the caller's read wins.
  Future<void> onCredentialMissing({required int epoch}) async {
    if (_retired || !mounted) return;
    final identity = state;
    if (identity.epoch != epoch || !identity.isAuthenticated) return;
    await _logout(
      expectedIdentity: identity,
      requireMissingToken: true,
    );
  }

  /// The account reconcile confirmed [accountId]/[address] belong to the
  /// identity that was current at [epoch]. Publishes [IdentityPhase.ready]
  /// (same epoch — this completes the identity, it doesn't replace it) and
  /// clears the crash-recovery marker.
  ///
  /// Returns false without touching anything when the identity has
  /// transitioned since — the marker stays set so the CURRENT identity's own
  /// reconcile repairs state.
  Future<bool> reconcileSucceeded({
    required int epoch,
    required String accountId,
    required String address,
    required int participantId,
    int? provisionedSeasonId,
  }) =>
      _transition(() async {
        if (state.epoch != epoch || state.phase != IdentityPhase.reconciling) {
          _log.warn('Discarding stale reconcile result '
              '(epoch $epoch vs ${state.epoch}, phase ${state.phase.name})');
          return false;
        }
        final bucket = NetworkPrefs.bucketForAddress(address);
        await _writeProvisionedSeason(bucket, provisionedSeasonId);
        // Persist the one-time legacy ownership migration before clearing the
        // recovery marker. A crash after the marker is cleared may restore
        // directly to ready only when this proof and the bucket owner id both
        // exist.
        await _writeLifecycleOwnershipConfirmed(bucket);
        await _clearReconcileMarker();
        // FIXME(follow-up): Pass clearProvisionedSeasonId when the response is
        // null; copyWith otherwise retains the old baseline and repeats the
        // rollover reconcile.
        _publish(state.copyWith(
          phase: IdentityPhase.ready,
          accountId: accountId,
          address: address,
          participantId: participantId,
          provisionedSeasonId: provisionedSeasonId,
        ));
        return true;
      }, whenRetired: () => false);

  /// The authoritative active season moved past the season this identity's
  /// account was provisioned for. Re-enter [IdentityPhase.reconciling] (new
  /// epoch: in-flight work bound to the old season identity must not apply)
  /// so the reconcile driver provisions the current season's account.
  ///
  /// The current account/bucket are kept — they still belong to the same
  /// USER — but wallet routes, signing, and node starts are gated until the
  /// reconcile settles the new season binding.
  /// A ready identity with a null baseline is an install upgraded from
  /// before season baselines were persisted — rollovers are undetectable
  /// for it. Route it through ONE reconcile (the `/wallet/provision`
  /// response establishes the baseline); the persisted flag keeps this from
  /// looping on every `/seasons` refresh if the backend returns no season id.
  Future<void> beginSeasonRollover({required int activeSeasonId}) =>
      _transition(() async {
        if (state.phase != IdentityPhase.ready) return;
        final provisioned = state.provisionedSeasonId;
        if (provisioned == activeSeasonId) return;
        if (provisioned == null) {
          if (await _readSeasonBaselineMigrated(state.bucket)) return;
          await _writeSeasonBaselineMigrated(state.bucket);
          _log.info('No provisioned-season baseline (pre-baseline install) - '
              'running one-time reconcile to establish it');
        } else {
          _log.info('Season rollover detected '
              '($provisioned -> $activeSeasonId) - reconciling account');
        }
        // Close the gate before the awaits below — same ordering rationale
        // as completeLogin.
        _publish(state.copyWith(
          epoch: state.epoch + 1,
          phase: IdentityPhase.reconciling,
        ));
        await _writeReconcileMarker();
        // The node is producing/signing under the previous season's account
        // binding; suspend it until the reconcile rebinds the runtime.
        await _suspendNode();
      }, whenRetired: () {});
}
