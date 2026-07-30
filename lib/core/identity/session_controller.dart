import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
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
        super(const Identity.unknown()) {
    IdentitySnapshots.publish(state);
  }

  static const _kReconcilePendingKeyBase = 'account:reconcile_pending';
  static const _kProvisionedSeasonKeyBase = 'identity:provisioned_season';

  final AuthTokenStore _tokenStore;
  final AuthGuestFlag _guestFlag;
  final AuthRepository _repository;

  /// Stops a running node when a transition makes account ownership unknown.
  /// Injectable for tests; the default touches the Rust backend (a no-op
  /// when the node was never started).
  final Future<void> Function() _suspendNode;

  static Future<void> _defaultSuspendNode() =>
      RustBackendService.instance.stopNode();

  Future<void>? _restoreFuture;
  Future<void> _queueTail = Future.value();

  /// Runs [body] after every previously queued transition has finished, so
  /// transitions never interleave.
  Future<T> _transition<T>(Future<T> Function() body) {
    final run = _queueTail.then((_) => body());
    _queueTail = run.then((_) {}, onError: (_) {});
    return run;
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
      if (ownerId != null) {
        // The last reconcile completed under this token's user (every login
        // sets the marker, and only a confirmed reconcile clears it and
        // writes the bucket's owner id).
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
    // account-scoped state. The marker must be persisted (it may be missing
    // on the ownership-unknown path) so a crash here still repairs on the
    // next boot.
    await _writeReconcileMarker();
    final staged = await loadParticipantIdInBucket(NetworkPrefs.guestBucket);
    _log.info('Boot restore requires account reconcile', context: {
      'hadMarker': pendingMarker,
      'hasActiveAccount': active != null,
      'hasStagedParticipantId': staged != null,
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
        // Marker + staged id BEFORE the token write: they are the
        // crash-recovery payload. If the token became boot-restorable first
        // and the app died, the participant id would exist only in the lost
        // AuthSession.
        await _writeReconcileMarker();
        await stageParticipantIdInGuestBucket(session.participant.id);
        await _tokenStore.write(session.token);
        await _guestFlag.clear();
        // A running node keeps signing/producing under whichever account was
        // active before this login. Ownership is now unknown — stop it. The
        // reconciler restarts it under the confirmed account.
        await _suspendNode();
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.reconciling,
          participantId: session.participant.id,
        ));
      });

  Future<void> continueAsGuest() => _transition(() async {
        await _guestFlag.setGuest();
        // A leftover staged id (interrupted earlier login) must not resolve
        // for an explicit guest session.
        await clearGuestParticipantId();
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.guest,
        ));
      });

  Future<void> logout() => _transition(() async {
        final token = await _tokenStore.read();
        if (token != null && token.isNotEmpty) {
          try {
            await _repository.logout(token);
          } catch (e) {
            _log.warn('Server-side logout failed (token cleared anyway): $e');
          }
        }
        await _tokenStore.clear();
        await _guestFlag.clear();
        await clearGuestParticipantId();
        await _clearReconcileMarker();
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));
      });

  /// A request authenticated under [epoch] came back 401. Ignored when the
  /// identity has already transitioned since — a late 401 from a previous
  /// session must not clear the newly written token.
  Future<void> onUnauthorized({required int epoch}) => _transition(() async {
        if (state.epoch != epoch) {
          _log.warn('Ignoring 401 from a request issued under epoch $epoch '
              '(current: ${state.epoch})');
          return;
        }
        await _tokenStore.clear();
        // A 401 invalidates the TOKEN, not the user's explicit guest choice.
        final guest = await _guestFlag.isGuest();
        if (guest) {
          _publish(Identity(
            epoch: state.epoch + 1,
            phase: IdentityPhase.guest,
          ));
          return;
        }
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));
      });

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
    required int? participantId,
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
        await _clearReconcileMarker();
        _publish(state.copyWith(
          phase: IdentityPhase.ready,
          accountId: accountId,
          address: address,
          participantId: participantId,
          provisionedSeasonId: provisionedSeasonId,
        ));
        return true;
      });

  /// The authoritative active season moved past the season this identity's
  /// account was provisioned for. Re-enter [IdentityPhase.reconciling] (new
  /// epoch: in-flight work bound to the old season identity must not apply)
  /// so the reconcile driver provisions the current season's account.
  ///
  /// The current account/bucket are kept — they still belong to the same
  /// USER — but wallet routes, signing, and node starts are gated until the
  /// reconcile settles the new season binding.
  Future<void> beginSeasonRollover({required int activeSeasonId}) =>
      _transition(() async {
        if (state.phase != IdentityPhase.ready) return;
        final provisioned = state.provisionedSeasonId;
        if (provisioned == null || provisioned == activeSeasonId) return;
        _log.info('Season rollover detected '
            '($provisioned -> $activeSeasonId) - reconciling account');
        await _writeReconcileMarker();
        _publish(state.copyWith(
          epoch: state.epoch + 1,
          phase: IdentityPhase.reconciling,
        ));
      });
}
