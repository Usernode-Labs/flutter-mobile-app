import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/services/identity_runtime_restart_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/SessionController');

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
  })  : _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _repository = repository,
        _suspendNode = suspendNode ?? _defaultSuspendNode,
        super(Identity.unknown(epoch: IdentitySnapshots.current.epoch)) {
    IdentitySnapshots.publish(state);
    NetworkPrefs.setActiveBucket(null, guest: true);
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

  /// Stops a running node when a transition makes account ownership unknown.
  /// Injectable for tests; the default touches the Rust backend (a no-op
  /// when the node was never started).
  final Future<void> Function() _suspendNode;

  static Future<void> _defaultSuspendNode() =>
      RustBackendService.instance.stopNode();

  bool _requestRuntimeRestart(String reason) {
    if (_retiredForRuntimeCutover) {
      // This transition was accepted before the host closed admission and is
      // already covered by its final barrier. Its durable target will be
      // restored by that cutover; enqueueing another restart would only tear
      // down the fresh replacement container again.
      _log.debug('Runtime already retiring; restart request is covered',
          context: {'reason': reason});
      return true;
    }
    return IdentityRuntimeRestartService.instance.request(reason: reason);
  }

  Future<void> _logoutBestEffort(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _repository.logout(token);
    } catch (e) {
      _log.warn('Server-side logout failed (token cleared anyway): $e');
    }
  }

  Future<void>? _restoreFuture;
  Future<void> _queueTail = Future.value();
  final Queue<Future<void> Function()> _pendingTransitions = Queue();
  bool _transitionActive = false;
  bool _retiredForRuntimeCutover = false;

  /// Completes when every transition queued so far has finished its
  /// persistence writes. Gate-closing transitions publish the new identity
  /// BEFORE they persist (so concurrent node starts / signing see the closed
  /// gate immediately); work triggered by that publish which needs the
  /// persisted side (e.g. the reconciler's authenticated provision call
  /// reading the just-written session token) awaits this first.
  Future<void> get transitionsSettled => _queueTail;

  /// Atomically closes this controller to new transitions and returns the
  /// final barrier for everything it had already accepted.
  ///
  /// The interactive runtime host calls this before unmounting the provider
  /// graph. Dart cannot interleave another synchronous call between setting
  /// the retirement flag and capturing [_queueTail], so a transition is
  /// either included in this barrier or refused by [_transition].
  Future<void> retireForRuntimeCutover() {
    _retiredForRuntimeCutover = true;
    return _queueTail;
  }

  /// Runs [body] after every previously queued transition has finished, so
  /// transitions never interleave. When idle, [body] starts synchronously so
  /// gate-closing publications happen before this method returns its Future.
  Future<void> _transition(Future<void> Function() body) =>
      _enqueueTransition(body, whenRetired: () {});

  Future<bool> _boolTransition(Future<bool> Function() body) =>
      _enqueueTransition(body, whenRetired: () => false);

  Future<T> _enqueueTransition<T>(
    Future<T> Function() body, {
    required T Function() whenRetired,
  }) {
    if (_retiredForRuntimeCutover) {
      _log.debug('Ignoring identity transition after runtime retirement');
      return Future<T>.sync(whenRetired);
    }

    final result = Completer<T>();

    Future<void> run() async {
      try {
        result.complete(await body());
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
  /// set after its recovery marker is durable but before the migration
  /// reconcile is published, so the migration cannot loop if the backend
  /// returns no season id or be skipped after a crash between those writes.
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

  /// A sign-in completed. The identity becomes [IdentityPhase.reconciling]
  /// until the account reconcile confirms which on-chain account this user
  /// owns — until then the node stays suspended, signing is refused, and the
  /// guest bucket is active so no other identity's data is read or written.
  Future<void> completeLogin(AuthSession session) => _transition(() async {
        final epoch = state.epoch + 1;
        // Close every account-sensitive gate without yet advertising an
        // authenticated session. Providers awakened by `reconciling` must
        // never observe the previous user's token under the new identity.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));
        // Replace the boot-restorable credential independently of node
        // shutdown. A shutdown timeout must leave the in-memory identity
        // fail-closed in `transitioning`, but it must never resurrect the old
        // session (or lose this new session) on the next process start.
        await _tokenStore.clear();
        // Marker + staged id BEFORE the token write: they are the
        // crash-recovery payload. If the token became boot-restorable first
        // and the app died, the participant id would exist only in the lost
        // AuthSession. (A crash before the token write loses only the
        // in-memory publish above — the next boot restores signed-out.)
        await _writeReconcileMarker();
        await stageParticipantIdInGuestBucket(session.participant.id);
        await _guestFlag.clear();
        await _tokenStore.write(session.token);
        await _suspendNode();
        if (_requestRuntimeRestart('login_completed')) return;
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.reconciling,
          participantId: session.participant.id,
        ));
      });

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
        if (_requestRuntimeRestart('guest_session_started')) return;
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.guest,
        ));
      });

  Future<bool> logout({Identity? expectedIdentity}) =>
      _boolTransition(() async {
        // Async bridge callbacks may have been authorized by a prior identity.
        if (expectedIdentity != null && !state.sameScopeAs(expectedIdentity)) {
          return false;
        }

        final epoch = state.epoch + 1;
        // Revoke every in-memory account-sensitive lease synchronously. The
        // durable credential is cleared below before the fallible producer
        // shutdown, and the settled identity is published only after it.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));
        final token = await _tokenStore.read();
        // Clear the boot-restorable credential before the best-effort network
        // request. A crash or app restart while /logout is slow must restore
        // signed out, not resurrect this session.
        await _tokenStore.clear();
        await _guestFlag.clear();
        await clearGuestParticipantId();
        await _clearReconcileMarker();
        // Credential revocation above is durable even when process-global node
        // shutdown fails. Do not publish a settled signed-out identity until
        // the producer is confirmed down.
        await _suspendNode();
        if (_requestRuntimeRestart('logout_completed')) {
          unawaited(_logoutBestEffort(token));
          return true;
        }
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));

        await _logoutBestEffort(token);
        return true;
      });

  /// A request carrying [credential] came back 401. It may invalidate only
  /// that exact identity epoch and token.
  Future<void> onUnauthorized({
    required AuthCredentialLease credential,
  }) =>
      _transition(() async {
        if (state.epoch != credential.epoch) {
          _log.warn('Ignoring 401 from a request issued under epoch '
              '${credential.epoch} '
              '(current: ${state.epoch})');
          return;
        }
        final currentToken = await _tokenStore.read();
        if (state.epoch != credential.epoch ||
            currentToken != credential.token) {
          _log.warn('Ignoring 401 for a credential that is no longer current');
          return;
        }
        final epoch = state.epoch + 1;
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));
        await _tokenStore.clear();
        await clearGuestParticipantId();
        await _clearReconcileMarker();
        // A 401 invalidates the TOKEN, not the user's explicit guest choice.
        final guest = await _guestFlag.isGuest();
        await _suspendNode();
        if (_requestRuntimeRestart('credential_rejected')) return;
        if (guest) {
          _publish(Identity(
            epoch: epoch,
            phase: IdentityPhase.guest,
          ));
          return;
        }
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));
      });

  /// Repairs an authenticated identity whose credential disappeared before a
  /// request could be sent. A token written since the caller's read wins.
  Future<void> onCredentialMissing({required int epoch}) =>
      _transition(() async {
        if (state.epoch != epoch || !state.isAuthenticated) return;
        final currentToken = await _tokenStore.read();
        if (state.epoch != epoch ||
            !state.isAuthenticated ||
            (currentToken != null && currentToken.isNotEmpty)) {
          return;
        }
        final nextEpoch = state.epoch + 1;
        _publish(Identity(
          epoch: nextEpoch,
          phase: IdentityPhase.transitioning,
        ));
        await _tokenStore.clear();
        await clearGuestParticipantId();
        await _clearReconcileMarker();
        final guest = await _guestFlag.isGuest();
        await _suspendNode();
        if (_requestRuntimeRestart('credential_missing')) return;
        if (guest) {
          _publish(Identity(
            epoch: nextEpoch,
            phase: IdentityPhase.guest,
          ));
          return;
        }
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: nextEpoch,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));
      });

  /// The account reconcile confirmed [accountId]/[address] belong to the
  /// identity that was current at [epoch]. After persisting that proof and
  /// clearing the crash-recovery marker, an interactive runtime is replaced;
  /// a headless/test container publishes [IdentityPhase.ready] in place.
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
      _boolTransition(() async {
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
        final readyIdentity = state.copyWith(
          phase: IdentityPhase.ready,
          accountId: accountId,
          address: address,
          participantId: participantId,
          provisionedSeasonId: provisionedSeasonId,
          clearProvisionedSeasonId: provisionedSeasonId == null,
        );
        // The request is delivered on the next event turn, so the gate still
        // closes synchronously before the runtime host can dispose us. The
        // replacement container restores the durable ready identity instead
        // of allowing providers created while reconciling to survive it.
        if (_requestRuntimeRestart('account_reconcile_completed')) {
          _publish(Identity(
            epoch: state.epoch + 1,
            phase: IdentityPhase.transitioning,
          ));
          return true;
        }
        _publish(readyIdentity);
        return true;
      });

  /// The authoritative active season moved past the season this identity's
  /// account was provisioned for. Re-enter [IdentityPhase.reconciling] (new
  /// epoch: in-flight work bound to the old season identity must not apply)
  /// so the reconcile driver provisions the current season's account.
  ///
  /// The participant id is staged as recovery state, but the old account
  /// bucket is not kept ambient: wallet routes, signing, and node starts stay
  /// gated until a replacement runtime reconciles the new season binding.
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
        var consumeBaselineMigration = false;
        if (provisioned == null) {
          if (await _readSeasonBaselineMigrated(state.bucket)) return;
          consumeBaselineMigration = true;
          _log.info('No provisioned-season baseline (pre-baseline install) - '
              'running one-time reconcile to establish it');
        } else {
          _log.info('Season rollover detected '
              '($provisioned -> $activeSeasonId) - reconciling account');
        }
        final previous = state;
        final epoch = previous.epoch + 1;
        // Close the gate before the durable cutover payload is written. The
        // replacement runtime must restore through the guest bucket and may
        // not inherit providers bound to the previous season.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));
        final participantId = previous.participantId;
        if (participantId != null) {
          await stageParticipantIdInGuestBucket(participantId);
        }
        await _writeReconcileMarker();
        // The pending marker is the crash-recovery authority. Only mark this
        // one-shot migration consumed after a restart is guaranteed to resume
        // reconciliation; the opposite order can permanently skip baseline
        // establishment if the process dies between the two writes.
        if (consumeBaselineMigration) {
          await _writeSeasonBaselineMigrated(previous.bucket);
        }
        // The node is producing/signing under the previous season's account
        // binding; suspend it until the reconcile rebinds the runtime.
        await _suspendNode();
        if (_requestRuntimeRestart('season_rollover')) return;
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.reconciling,
          participantId: participantId,
        ));
      });
}
