import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/identity/session_scope_reset.dart';
import 'package:crypto_mobile_app/core/identity/sign_out_fence.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

final _log = LoggingService.instance.withTag('usernode/SessionController');

typedef SessionTerminalReset = Future<void> Function({
  required String reason,
  Future<void> Function()? prepareNextLaunch,
});

/// Work was submitted after this controller entered a terminal boundary.
class SessionControllerRetiredException implements Exception {
  const SessionControllerRetiredException();

  @override
  String toString() => 'SessionControllerRetiredException()';
}

enum _SessionValidation { valid, invalid, unavailable }

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider = Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

/// Bumped exactly once per COMPLETED voluntary sign-out — after the bearer,
/// the node runtime, the native generation, the session prefs and the WebView
/// session jar are all gone.
///
/// Document replacement is driven from THIS edge rather than from
/// `authenticated -> anything else`: `logout` publishes
/// [IdentityPhase.transitioning] synchronously before its first await (so
/// in-flight work sees a closed gate), and that publication maps to
/// [AuthStatus.unknown] — a WebView replaced on it would race the very
/// cookie/storage deletion that makes the next load render a login page.
/// Terminal boundaries never reach this signal at all.
final signOutCompletionProvider = StateProvider<int>((ref) => 0);

/// The single source of truth for the app's current [Identity].
///
/// All identity transitions go through [SessionController]; everything else
/// only reads. Watch this (or a `select` on it) from any provider whose
/// output depends on WHO the user is — auth status, account bucket, or
/// participant id.
final identityProvider = StateNotifierProvider<SessionController, Identity>(
  (ref) {
    final tokenStore = ref.watch(authTokenStoreProvider);
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: ref.watch(authGuestFlagProvider),
      repository: ref.watch(authRepositoryProvider),
      resetSessionScopedProcessState: () => resetSessionScopedProcessState(ref),
      onSignOutCompleted: () {
        final signal = ref.read(signOutCompletionProvider.notifier);
        signal.state = signal.state + 1;
      },
    );

    var disposed = false;

    void restoreWhenAvailable({bool retryAfterCurrent = false}) {
      unawaited(() async {
        try {
          await controller.restore();
          if (retryAfterCurrent && !disposed) {
            // The protected-data event can race the failing storage reply. In
            // that ordering the first call merely joins the in-flight restore;
            // the second runs after it has released its retry slot.
            await controller.restore();
          }
        } on SessionControllerRetiredException {
          // Provider disposal retires an in-flight restore; there is no graph
          // left for a retry to update.
        } catch (error, stackTrace) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      }());
    }

    final protectedDataSubscription = tokenStore
        .protectedDataAvailabilityChanges
        ?.where((available) => available)
        .listen((_) => restoreWhenAvailable(retryAfterCurrent: true));
    ref.onDispose(() {
      disposed = true;
      final subscription = protectedDataSubscription;
      if (subscription != null) unawaited(subscription.cancel());
    });
    restoreWhenAvailable();
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
    Future<bool> Function()? clearWebSessionData,
    Future<bool> Function()? rotateNativeGeneration,
    Future<bool> Function()? clearSessionNotifications,
    Future<void> Function()? resetSessionScopedProcessState,
    void Function()? onSignOutCompleted,
    SignOutFence? signOutFence,
    SessionTerminalReset? terminalReset,
  })  : _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _repository = repository,
        _suspendNode = suspendNode ?? _defaultSuspendNode,
        _clearWebSessionData =
            clearWebSessionData ?? _defaultClearWebSessionData,
        _rotateNativeGeneration =
            rotateNativeGeneration ?? _defaultRotateNativeGeneration,
        _clearSessionNotifications =
            clearSessionNotifications ?? _defaultClearSessionNotifications,
        _resetSessionScopedProcessState = resetSessionScopedProcessState,
        _onSignOutCompleted = onSignOutCompleted,
        _signOutFence = signOutFence ?? DurableSignOutFence(),
        _terminalReset = terminalReset ?? _defaultTerminalReset,
        super(Identity.unknown(epoch: IdentitySnapshots.current.epoch)) {
    IdentitySnapshots.publish(state);
  }

  static const _kReconcilePendingKeyBase = 'account:reconcile_pending';
  static const _kLifecycleOwnershipConfirmedKeyBase =
      'identity:lifecycle_ownership_confirmed';

  final AuthTokenStore _tokenStore;
  final AuthGuestFlag _guestFlag;
  final AuthRepository _repository;

  /// Stops a running node when a transition makes account ownership unknown.
  /// Injectable for tests; the default touches the Rust backend (a no-op
  /// when the node was never started).
  final Future<void> Function() _suspendNode;

  /// Clears the WKWebView/WebView cookie + storage jar backing the platform
  /// shell. A sign-out that left it in place would reload straight back into
  /// an authenticated page. Injectable for tests; the default crosses the
  /// native method channel.
  final Future<bool> Function() _clearWebSessionData;

  /// Retires the native application-incarnation token and issues a fresh one.
  /// Durable native work (alarms, the watchdog, headless recovery events)
  /// captured the retired token, so rotating it is what stops a background
  /// engine from restarting a producer for the signed-out account. Injectable
  /// for tests; the default crosses the native method channel.
  final Future<bool> Function() _rotateNativeGeneration;

  /// Removes notifications the retired session has already posted.
  final Future<bool> Function() _clearSessionNotifications;

  /// Drops identity-agnostic PROCESS state that outlives a scoped sign-out
  /// (in-memory debug buffers, provider caches that captured the retired
  /// identity). Null in unit tests that own no provider graph.
  final Future<void> Function()? _resetSessionScopedProcessState;

  /// Fired once a voluntary sign-out has fully settled — see
  /// [signOutCompletionProvider].
  final void Function()? _onSignOutCompleted;

  /// The durable journal that makes bearer retirement and namespace
  /// retirement crash-atomic as a pair. Injectable for tests; the default is
  /// file-backed (see [DurableSignOutFence] for why a preference is not
  /// good enough).
  final SignOutFence _signOutFence;

  final SessionTerminalReset _terminalReset;

  static Future<void> _defaultSuspendNode() async {
    // Not `RustBackendService.stopNode()`: that leaves the coordinator's
    // intent/account facts, Android monitoring, the foreground service and
    // wakelock, watchdog recovery and every scheduled alarm armed, so a
    // headless recovery event could still restart production for the identity
    // this boundary is retiring.
    await NodeLifecycleCoordinator.instance
        .standDown(reason: 'identity_boundary');
    await EpochSlotSchedulerService.instance.closeForSignOut();
    // The sleep service is deliberately outside the coordinator (it owns a
    // richer state machine), and its resume flags were captured while the
    // retired identity's node was running. Awaited: it drains its own queued
    // transitions, which would otherwise re-arm the wakelock and monitoring
    // after this teardown.
    await AppSleepService.instance.closeForSignOut();
  }

  static Future<bool> _defaultClearWebSessionData() =>
      PlatformAlarmService.instance.clearWebSessionData();

  static Future<bool> _defaultRotateNativeGeneration() =>
      PlatformAlarmService.instance.rotateApplicationIncarnation();

  static Future<bool> _defaultClearSessionNotifications() =>
      PlatformAlarmService.instance.clearSessionNotifications();

  static Future<void> _defaultTerminalReset({
    required String reason,
    Future<void> Function()? prepareNextLaunch,
  }) =>
      AppResetService.instance.resetAndTerminate(
        reason: reason,
        prepareNextLaunch: prepareNextLaunch,
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
    if (!mounted) return;
    IdentitySnapshots.publish(next);
    NetworkPrefs.setActiveBucket(
      next.address,
      guest: next.address == null,
    );
    state = next;
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

  // -- transitions ------------------------------------------------------------

  /// Resolve the boot identity. Idempotent: concurrent/repeated calls share
  /// one run. Network-free — a settled previous session restores directly to
  /// [IdentityPhase.ready]; only an interrupted login (persisted reconcile
  /// marker) or an account/bucket mismatch routes through
  /// [IdentityPhase.reconciling].
  Future<void> restore() {
    final existing = _restoreFuture;
    if (existing != null) return existing;

    late Future<void> run;
    run = _transition(() async {
      var nextEpoch = state.epoch + 1;
      // Honoured BEFORE any account lookup: a sign-out that died between
      // retiring the bearer and retiring the namespace would otherwise
      // resolve the previous user's active account here and publish it as
      // a locally-signable identity.
      final interruptedSignOut = await _signOutFence.isRaised();
      if (!mounted) return;
      if (interruptedSignOut) {
        _log.warn('Completing a sign-out interrupted before it settled');
        _publish(Identity(
          epoch: nextEpoch,
          phase: IdentityPhase.transitioning,
        ));
        nextEpoch += 1;
        final sessionEnded = await _endSessionScopeGuarded();
        if (!mounted) return;
        if (!sessionEnded) {
          _retired = true;
          await _terminalReset(reason: 'signout_cleanup_unconfirmed');
          return;
        }
      }
      final token = await _tokenStore.read();
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        await _restoreAuthenticated(epoch: nextEpoch);
        return;
      }
      final guest = await _guestFlag.isGuest();
      if (!mounted) return;
      if (guest) {
        _publish(Identity(
          epoch: nextEpoch,
          phase: IdentityPhase.guest,
        ));
        return;
      }
      // No session: local-only mode. The bucket follows the active local
      // account (its owner is offline-irrelevant — no token can act as
      // anyone), matching pre-auth behavior.
      final active = await (await AccountsRepository.create()).getActive();
      if (!mounted) return;
      _publish(Identity(
        epoch: nextEpoch,
        phase: IdentityPhase.unauthenticated,
        accountId: active?.id,
        address: active?.address,
      ));
    }).catchError((Object error, StackTrace stackTrace) {
      if (error is AuthTokenUnavailableException) {
        if (identical(_restoreFuture, run)) {
          // A later protected-data event may now start a fresh restore.
          _restoreFuture = null;
        }
        if (mounted) {
          _log.warn(
            'Session credential is temporarily unavailable; '
            'waiting for protected data',
          );
        }
        // Unavailable is an expected unresolved boot state, not a failed app
        // bootstrap. Keep Identity unknown until a protected-data retry.
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _restoreFuture = run;
    return run;
  }

  Future<void> _restoreAuthenticated({required int epoch}) async {
    final pendingMarker = await _readReconcileMarker();
    if (!mounted) return;
    final repo = await AccountsRepository.create();
    if (!mounted) return;
    final active = await repo.getActive();
    if (!mounted) return;

    if (!pendingMarker && active != null) {
      final bucket = NetworkPrefs.bucketForAddress(active.address);
      final ownerId = await loadParticipantIdInBucket(bucket);
      if (!mounted) return;
      final lifecycleOwnershipConfirmed =
          await _readLifecycleOwnershipConfirmed(bucket);
      if (!mounted) return;
      if (ownerId != null && lifecycleOwnershipConfirmed) {
        // The last reconcile completed under this lifecycle protocol (every
        // login sets the marker, and only a confirmed reconcile clears it and
        // records lifecycle ownership for the bucket).
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.ready,
          participantId: ownerId,
          accountId: active.id,
          address: active.address,
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
      if (!mounted) return;
    } else {
      await clearGuestParticipantId();
      if (!mounted) return;
      await _writeReconcileMarker();
      if (!mounted) return;
    }
    _log.info('Boot restore requires account reconcile', context: {
      'hadMarker': pendingMarker,
      'hasActiveAccount': active != null,
      'hasStagedParticipantId': staged != null,
      'legacyOwnershipMigration': !pendingMarker && active != null,
    });
    _publish(Identity(
      epoch: epoch,
      phase: IdentityPhase.reconciling,
      participantId: staged,
    ));
  }

  /// Accepts an authoritative authenticated session.
  ///
  /// Initial login and a renewed credential for the current participant are
  /// applied in place. A direct different-participant login is discarded and
  /// forces the current authenticated incarnation through its terminal reset.
  Future<bool> completeLogin(
    AuthSession session, {
    Identity? expectedIdentity,
  }) =>
      _transition(() async {
        // The web login may wait for JavaScript acknowledgement before it
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
          // The namespace is refreshed here too: it is stable per user, so a
          // renewal only ever rewrites the same value — except on an install
          // upgraded from a server that did not issue one yet, which is
          // exactly when it needs recording.
          await saveIdentityNamespace(session.participant.identityHash);
          final replacedToken = await _tokenStore.read();
          await _tokenStore.write(session.token);
          if (replacedToken != null &&
              replacedToken.isNotEmpty &&
              replacedToken != session.token) {
            unawaited(_logoutBestEffort(replacedToken));
          }
          return true;
        }

        final epoch = current.epoch + 1;
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));

        if (!current.isAuthenticated) {
          // Guests and unauthenticated sessions own no node runtime. Keep the
          // web session that established this login alive while the new
          // account is reconciled, then let the platform request its start.
          await _persistLoginTarget(session);
          await _suspendNode();
          _publish(Identity(
            epoch: epoch,
            phase: IdentityPhase.reconciling,
            participantId: participantId,
          ));
          return true;
        }

        _retired = true;
        unawaited(_logoutStoredTokenBestEffort());
        unawaited(_logoutBestEffort(session.token));
        await _terminalReset(reason: 'different_participant_login');
        return false;
      }, whenRetired: () => false);

  Future<void> _persistLoginTarget(AuthSession session) async {
    await _tokenStore.clear();
    // Marker + staged id BEFORE the token write are the crash-recovery
    // payload. A boot-restorable token therefore always restores through the
    // authoritative account reconcile until ownership is committed.
    await _writeReconcileMarker();
    // The storage namespace belongs to that payload: the reconcile resolves
    // the account registry through it, so a boot-restorable token must never
    // be able to reach the PREVIOUS user's registry. Boot restore is
    // network-free and cannot re-derive it, which is why it is persisted here
    // rather than read from `/me` on demand.
    await saveIdentityNamespace(session.participant.identityHash);
    await stageParticipantIdInGuestBucket(session.participant.id);
    await _guestFlag.clear();
    await _tokenStore.write(session.token);
  }

  Future<void> continueAsGuest() => _transition(() async {
        if (state.isAuthenticated) {
          final epoch = state.epoch + 1;
          _publish(Identity(
            epoch: epoch,
            phase: IdentityPhase.transitioning,
          ));
          _retired = true;
          unawaited(_logoutStoredTokenBestEffort());
          await _terminalReset(reason: 'authenticated_to_guest');
          return;
        }
        final epoch = state.epoch + 1;
        // Close signing/node gates before waiting for any leftover producer to
        // stop. This remains safe if explicit guest-node admission is added in
        // the future; today guest starts are refused at the backend boundary.
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

  /// Voluntary sign-out. The one identity boundary that is NOT terminal.
  ///
  /// Every other boundary tears the incarnation down and asks the platform to
  /// die, which iOS cannot do — leaving the user on the inert "close and
  /// reopen" surface. A deliberate sign-out has no such need: the process, its
  /// process-global services and the user's local accounts all survive, and
  /// the shell reloads into the platform's own login page (login is
  /// platform-owned; there is no native login screen to route to).
  ///
  /// What must not survive is the session — and because the process does,
  /// every boundary terminal reset used to supply by erasing everything has to
  /// be closed here explicitly. [_endSessionScope] owns that list and its
  /// crash-safe order; a mandatory purge it cannot confirm escalates to the
  /// terminal reset instead of being acknowledged.
  ///
  /// Account-scoped state (the wallet, its bucket-scoped prefs, a pending ZK
  /// completion) is deliberately KEPT: it belongs to that user's on-chain
  /// account rather than to the session, and it is already segregated both by
  /// bucket and by the storage namespace. The same user signing back in finds
  /// it; a different user never resolves it — provided a valid namespace
  /// proves that segregation, which [_clearSessionScopedState] enforces.
  Future<bool> logout({Identity? expectedIdentity}) => _transition(() async {
        // Async bridge callbacks may have been authorized by a prior identity.
        if (expectedIdentity != null && !state.sameScopeAs(expectedIdentity)) {
          return false;
        }
        final current = state;
        if (!current.isAuthenticated) return false;

        final epoch = current.epoch + 1;
        // Close every account-sensitive gate before the first await, so an
        // in-flight signer or node start sees the closed gate rather than a
        // half-dismantled session.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.transitioning,
        ));

        // Local revocation is what actually ends the session on this device,
        // so it must not be conditional on the server answering.
        String? token;
        try {
          token = await _tokenStore.read();
        } catch (error) {
          _log.warn('Could not read the bearer before sign-out: $error');
        }

        unawaited(_logoutBestEffort(token));

        if (!await _endSessionScopeGuarded()) {
          // A MANDATORY purge could not be confirmed. The session must still
          // end, and the only boundary that is guaranteed to close what is
          // left is the terminal one — so take it rather than acknowledging a
          // sign-out whose fences are still open.
          _retired = true;
          await _terminalReset(reason: 'signout_cleanup_unconfirmed');
          return false;
        }

        // Mirror what a cold boot with no session resolves to, so sign-out and
        // the next launch agree: local-only mode, following whatever account
        // the (now un-namespaced) registry still exposes.
        final active = await (await AccountsRepository.create()).getActive();
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.unauthenticated,
          accountId: active?.id,
          address: active?.address,
        ));
        _onSignOutCompleted?.call();
        return true;
      }, whenRetired: () => false);

  /// How long the whole mandatory boundary may take before it is treated as
  /// unconfirmed. Every step is bounded individually, but a native reply that
  /// never arrives (or a Rust shutdown that never settles) must not leave the
  /// app parked in `transitioning` forever.
  static const _signOutBoundaryTimeout = Duration(seconds: 30);

  /// [_endSessionScope] with every failure mode funnelled into one answer.
  ///
  /// The steps are fallible in more ways than a `false` return:
  /// `RustBackendService.stopNode()` deliberately THROWS when process-global
  /// shutdown cannot be confirmed, preference and native calls can throw, and
  /// a native reply can simply never come. Left uncaught, such an exception
  /// escapes the transition, the bridge resolves logout as a plain failure,
  /// the identity stays in `transitioning`, and nothing — no completion, no
  /// document replacement, no terminal reset — happens in this process. Every
  /// one of those becomes `signout_cleanup_unconfirmed` here, with the fence
  /// still raised so an interrupted boundary is repaired on the next boot too.
  Future<bool> _endSessionScopeGuarded() async {
    try {
      return await _endSessionScope().timeout(_signOutBoundaryTimeout);
    } catch (error, stackTrace) {
      _log.error(
        'Sign-out cleanup could not be confirmed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Everything a sign-out has to make true, in the one order that survives a
  /// crash at any point. Factored out because [restore] repairs an
  /// interrupted sign-out by running exactly the same boundary.
  ///
  /// Returns false when a mandatory purge could not be confirmed; callers go
  /// through [_endSessionScopeGuarded], which also converts a throw or a hang
  /// into the same answer.
  Future<bool> _endSessionScope() async {
    // Durable BEFORE the bearer disappears: from here on, a cold boot that
    // finds this fence completes the sign-out instead of resolving the
    // half-retired session. An unconfirmable fence means the pair is no longer
    // crash-atomic, so the bearer is not touched and the caller fails closed.
    if (!await _signOutFence.raise()) {
      _log.error('Could not raise a durable sign-out fence');
      return false;
    }
    await _tokenStore.clear();

    // Retire the native generation before the runtime teardown, so an alarm,
    // watchdog tick or headless recovery event that lands DURING the teardown
    // is already rejected as stale instead of racing it back into a producer
    // start. Unconfirmed rotation leaves that race open, so it fails closed.
    if (!await _rotateNativeGeneration()) {
      _log.error('Could not retire the native generation for sign-out');
      return false;
    }
    await _suspendNode();
    if (!await _clearSessionScopedState()) return false;
    if (!await _clearWebSession()) return false;
    await _resetSessionScopedProcessState?.call();
    // Tray/lock-screen text is not a fail-closed boundary — it leaks no
    // authority — but it is the retired session's content, so it is cleared
    // here rather than left for the next user to read.
    try {
      if (!await _clearSessionNotifications()) {
        _log.warn('Native session-notification clear reported failure');
      }
    } catch (error) {
      _log.warn('Could not clear session notifications: $error');
    }
    // Best-effort: a stale fence only costs one redundant repair next boot.
    await _signOutFence.lower();
    return true;
  }

  /// Drops everything belonging to the SESSION rather than to the user's
  /// account. Account-scoped (bucket-prefixed) state stays — see [logout].
  ///
  /// Returns false when a step that gates cross-user segregation could not be
  /// confirmed.
  Future<bool> _clearSessionScopedState() async {
    await _guestFlag.clear();
    // A leftover marker would make the next boot believe a login was
    // interrupted and route a session-less app into reconciliation.
    await _clearReconcileMarker();
    // I4: the guest bucket must never hold a signed-out user's id.
    await clearGuestParticipantId();
    if (!await _retireUnsegregatedRegistry()) return false;
    // Without this the signed-out user's account registry stays resolvable,
    // and the next user to sign in would adopt their accounts.
    if (!await clearIdentityNamespace()) {
      _log.error('Could not retire the identity namespace at sign-out');
      return false;
    }
    return true;
  }

  /// Leaves no account registry behind that cannot be attributed to one user.
  ///
  /// A non-null namespace does NOT prove the bare `accounts:*` keys are
  /// absent: a same-participant renewal can acquire a namespace for a registry
  /// that is still bare, and an interrupted legacy adoption leaves both
  /// copies. So the pending adoption is forced to completion FIRST — while the
  /// namespace is still valid, so a wallet that CAN be attributed is moved
  /// rather than dropped — and only then are the bare keys retired
  /// unconditionally. What survives that is a registry no identity owns, and
  /// keeping it would republish the signed-out user's wallet as signable
  /// local-only state (I15/`allowsSigning`) for whoever signs in next.
  Future<bool> _retireUnsegregatedRegistry() async {
    try {
      // Constructing the repository runs the legacy adoption.
      await AccountsRepository.create();
    } catch (error) {
      _log.warn('Could not complete the pending registry adoption: $error');
    }
    if (await AccountsRepository.retireUnnamespacedRegistry()) return true;
    _log.error('Could not retire the unnamespaced account registry');
    return false;
  }

  /// The WebView session jar is a security boundary, not a nicety: a retained
  /// cookie/storage set silently re-authenticates the next page load. Every
  /// failure mode (a `false` reply, a timeout, a throw) is therefore retried
  /// once and then reported as unconfirmed rather than warned about.
  Future<bool> _clearWebSession() async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        if (await _clearWebSessionData()) return true;
        _log.warn('Native web-session clear reported failure '
            '(attempt $attempt)');
      } catch (error) {
        _log.warn('Could not clear the web session (attempt $attempt): '
            '$error');
      }
    }
    _log.error('Web session could not be confirmed clear');
    return false;
  }

  Future<bool> _logout({
    Identity? expectedIdentity,
    String? expectedToken,
    bool requireMissingToken = false,
    String reason = 'logout',
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
        _retired = true;
        if (token != null && token.isNotEmpty) {
          unawaited(_logoutBestEffort(token));
        } else if (!requireMissingToken) {
          unawaited(_logoutStoredTokenBestEffort());
        }
        await _terminalReset(reason: reason);
        return true;
      }, whenRetired: () => false);

  Future<void> _logoutStoredTokenBestEffort() async {
    try {
      await _logoutBestEffort(await _tokenStore.read());
    } catch (e) {
      _log.warn('Could not read token for best-effort server logout: $e');
    }
  }

  Future<void> _logoutBestEffort(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _repository.logout(token);
    } catch (e) {
      _log.warn('Server-side logout failed (local reset still proceeds): $e');
    }
  }

  /// Checks a reported 401 against the endpoint that owns mobile sessions.
  /// A transient failure to perform that check is not evidence that the
  /// credential is invalid, so it must preserve the current identity.
  Future<_SessionValidation> _validateSessionCredential(
    Identity identity,
    String token,
  ) async {
    try {
      final session = await _repository.resolveBearerSession(token);
      final participantId = identity.participantId;
      if (participantId != null && session.participant.id != participantId) {
        _log.warn(
          'Session authority resolved the current credential to participant '
          '${session.participant.id}, expected $participantId',
        );
        return _SessionValidation.invalid;
      }
      return _SessionValidation.valid;
    } on AuthException catch (error) {
      if (error.kind == AuthErrorKind.invalidCredentials) {
        return _SessionValidation.invalid;
      }
      _log.warn(
        'Could not confirm a reported 401 with the session authority; '
        'preserving the current session: $error',
      );
      return _SessionValidation.unavailable;
    } catch (error) {
      _log.warn(
        'Could not confirm a reported 401 with the session authority; '
        'preserving the current session: $error',
      );
      return _SessionValidation.unavailable;
    }
  }

  /// A request carrying [credential] came back 401. It may invalidate only
  /// that exact identity epoch and token, and only after the session authority
  /// independently rejects the credential.
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

    final currentToken = await _tokenStore.read();
    if (_retired ||
        !mounted ||
        !state.sameScopeAs(identity) ||
        currentToken != credential.token) {
      _log.warn('Ignoring 401 for a credential that is no longer current');
      return;
    }

    final validation =
        await _validateSessionCredential(identity, credential.token);
    if (validation == _SessionValidation.valid) {
      _log.warn(
        'Ignoring 401 because the session authority still accepts the '
        'current credential',
      );
      return;
    }
    if (validation == _SessionValidation.unavailable) return;

    final loggedOut = await _logout(
      expectedIdentity: identity,
      expectedToken: credential.token,
      reason: 'session_expired',
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
      reason: 'session_credential_missing',
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
  }) =>
      _transition(() async {
        if (state.epoch != epoch || state.phase != IdentityPhase.reconciling) {
          _log.warn('Discarding stale reconcile result '
              '(epoch $epoch vs ${state.epoch}, phase ${state.phase.name})');
          return false;
        }
        final bucket = NetworkPrefs.bucketForAddress(address);
        // Persist the one-time legacy ownership migration before clearing the
        // recovery marker. A crash after the marker is cleared may restore
        // directly to ready only when this proof and the bucket owner id both
        // exist.
        await _writeLifecycleOwnershipConfirmed(bucket);
        await _clearReconcileMarker();
        _publish(state.copyWith(
          phase: IdentityPhase.ready,
          accountId: accountId,
          address: address,
          participantId: participantId,
        ));
        return true;
      }, whenRetired: () => false);
}
