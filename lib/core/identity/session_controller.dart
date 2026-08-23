import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_cleanup.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/identity/session_retirement_repair.dart';
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

typedef SessionDataPreservingTermination = Future<void> Function({
  required String reason,
});

/// Work was submitted after this controller entered a terminal boundary.
class SessionControllerRetiredException implements Exception {
  const SessionControllerRetiredException();

  @override
  String toString() => 'SessionControllerRetiredException()';
}

enum _SessionValidation { valid, invalid, ownerMismatch, unavailable }

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider = Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

/// Production bootstrap overrides this with the already-admitted process
/// authority. Null keeps isolated compatibility tests off native storage until
/// the remaining legacy controller path is removed.
final sessionAuthorityGatewayProvider =
    Provider<SessionAuthorityGateway?>((ref) => null);

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
/// output depends on WHO the user is — auth status, account bucket,
/// participant id, or season binding.
final identityProvider = StateNotifierProvider<SessionController, Identity>(
  (ref) {
    final controller = SessionController(
      tokenStore: ref.watch(authTokenStoreProvider),
      guestFlag: ref.watch(authGuestFlagProvider),
      repository: ref.watch(authRepositoryProvider),
      resetSessionScopedProcessState: () => resetSessionScopedProcessState(ref),
      onSignOutCompleted: () {
        final signal = ref.read(signOutCompletionProvider.notifier);
        signal.state = signal.state + 1;
      },
      sessionAuthority: ref.watch(sessionAuthorityGatewayProvider),
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
    Future<bool> Function()? clearWebSessionData,
    Future<bool> Function()? rotateNativeGeneration,
    Future<bool> Function()? clearSessionNotifications,
    Future<void> Function()? resetSessionScopedProcessState,
    void Function()? onSignOutCompleted,
    SignOutFence? signOutFence,
    SessionTerminalReset? terminalReset,
    SessionDataPreservingTermination? terminatePreservingData,
    SessionAuthorityGateway? sessionAuthority,
    String Function(String kind)? newAuthorityId,
    RetireRuntimeAuthority? retireRuntimeAuthority,
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
        _terminatePreservingData =
            terminatePreservingData ?? _defaultTerminatePreservingData,
        _sessionAuthority = sessionAuthority,
        _newAuthorityId = newAuthorityId ?? _defaultNewAuthorityId,
        _retireRuntimeAuthority = retireRuntimeAuthority,
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
  final SessionDataPreservingTermination _terminatePreservingData;
  final SessionAuthorityGateway? _sessionAuthority;
  final String Function(String kind) _newAuthorityId;
  final RetireRuntimeAuthority? _retireRuntimeAuthority;
  Map<String, dynamic>? _authorityRevisionValue;

  static String _defaultNewAuthorityId(String kind) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return '$kind-${base64Url.encode(bytes).replaceAll('=', '')}';
  }

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

  static Future<void> _defaultTerminatePreservingData({
    required String reason,
  }) =>
      AppResetService.instance.terminatePreservingData(reason: reason);

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

  Map<String, dynamic> get _authorityRevision =>
      _authorityRevisionValue ??
      (throw StateError('Session authority has not been restored'));

  Future<Map<String, dynamic>> _authorityCommand(
    Map<String, dynamic> request,
  ) async {
    final authority = _sessionAuthority;
    if (authority == null) {
      throw StateError('Session authority is not configured');
    }
    final reply = await authority.command(request);
    _adoptAuthorityReply(reply);
    return reply;
  }

  void _adoptAuthorityReply(Map<String, dynamic> reply) {
    _authorityRevisionValue = _map(reply['revision'], 'revision');
  }

  Map<String, dynamic> _replyState(
    Map<String, dynamic> reply, {
    required String expectedKind,
  }) {
    final authorityState = _replyStateFromRecord(reply);
    if (authorityState['kind'] != expectedKind) {
      throw StateError(
        'Expected session authority $expectedKind, got '
        '${authorityState['kind']}',
      );
    }
    return authorityState;
  }

  Map<String, dynamic> _replyStateFromRecord(Map<String, dynamic> reply) =>
      _map(_map(reply['record'], 'record')['state'], 'record.state');

  String _replyNetwork(Map<String, dynamic> reply) =>
      _string(_map(reply['record'], 'record')['network'], 'record.network');

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

  Future<bool> _clearReconcileMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reconcileMarkerKey);
    await prefs.reload();
    return !prefs.containsKey(_reconcileMarkerKey);
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
        if (_sessionAuthority != null) {
          await _restoreFromSessionAuthority();
          return;
        }
        // Honoured BEFORE any account lookup: a sign-out that died between
        // retiring the bearer and retiring the namespace would otherwise
        // resolve the previous user's active account here and publish it as
        // a locally-signable identity.
        if (await _signOutFence.isRaised()) {
          _log.warn('Completing a sign-out interrupted before it settled');
          _publish(Identity(
            epoch: state.epoch + 1,
            phase: IdentityPhase.transitioning,
          ));
          if (!await _endSessionScopeGuarded()) {
            _retired = true;
            await _terminalReset(reason: 'signout_cleanup_unconfirmed');
            return;
          }
        }
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
        // No session: retained wallets stay stored but are not addressable
        // until a login and backend reconciliation prove their owner.
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.unauthenticated,
        ));
      });

  Future<void> _restoreFromSessionAuthority() async {
    final reply = await _authorityCommand({'command': 'read_record'});
    final record = _map(reply['record'], 'record');
    final authorityState = _map(record['state'], 'record.state');
    final kind = authorityState['kind'];
    if (kind == 'logged_out') {
      _publish(Identity(
        epoch: state.epoch + 1,
        phase: authorityState['mode'] == 'guest'
            ? IdentityPhase.guest
            : IdentityPhase.unauthenticated,
        sessionId: _string(authorityState['session_id'], 'session_id'),
      ));
      return;
    }
    if (kind == 'ready') {
      await _restoreReadyAuthority(authorityState);
      return;
    }
    if (kind == 'activating') {
      await _restoreActivatingAuthority(reply);
      return;
    }
    if (kind == 'retiring') {
      _publish(Identity(
        epoch: state.epoch + 1,
        phase: IdentityPhase.transitioning,
        sessionId: _string(authorityState['session_id'], 'session_id'),
      ));
      if (!await _signOutFence.raise()) {
        await _authorityTerminalReset('signout_fence_unconfirmable');
        return;
      }
      final completed = await _repairAuthorityRetirement(reply);
      if (completed == null) {
        await _authorityTerminalReset('retirement_repair_failed');
        return;
      }
      final loggedOut = _replyState(completed, expectedKind: 'logged_out');
      await _publishAuthorityLoggedOut(loggedOut, signalCompletion: false);
      return;
    }
    if (kind == 'terminal_reset_required') {
      await _authorityTerminalReset(
        authorityState['reason'] is String
            ? authorityState['reason'] as String
            : 'session_authority_terminal',
      );
      return;
    }
    throw StateError('Session authority cannot restore state: $kind');
  }

  Future<void> _restoreActivatingAuthority(
    Map<String, dynamic> initialReply,
  ) async {
    var reply = initialReply;
    while (true) {
      final record = _map(reply['record'], 'record');
      final authorityState = _map(record['state'], 'record.state');
      final kind = authorityState['kind'];
      if (kind == 'ready') {
        await _restoreReadyAuthority(authorityState);
        return;
      }
      if (kind == 'logged_out') {
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: authorityState['mode'] == 'guest'
              ? IdentityPhase.guest
              : IdentityPhase.unauthenticated,
          sessionId: _string(authorityState['session_id'], 'session_id'),
        ));
        return;
      }
      if (kind == 'terminal_reset_required') {
        await _authorityTerminalReset(
          authorityState['reason'] is String
              ? authorityState['reason'] as String
              : 'activation_repair_terminal',
        );
        return;
      }
      if (kind != 'activating') {
        throw StateError('Activation repair found authority state $kind');
      }

      final phase = _string(authorityState['phase'], 'activation.phase');
      final sessionId =
          _string(authorityState['session_id'], 'activation.session_id');
      final transitionId = _string(
        authorityState['transition_id'],
        'activation.transition_id',
      );
      final rollbackId =
          authorityState['rollback_logged_out_session_id'] as String? ??
              _newAuthorityId('rollback');

      if (phase == 'persist_credential') {
        SessionCredential? credential;
        try {
          credential = await _tokenStore.readActivationCredential(
            sessionId,
            transitionId,
          );
        } on SessionCredentialOwnershipException {
          reply = await _activationEvidence(
            const {'kind': 'conflicting_owner'},
          );
          continue;
        } catch (_) {
          reply = await _activationEvidence(
            const {'kind': 'unconfirmable_boundary'},
          );
          continue;
        }
        if (credential == null) {
          reply = await _activationEvidence(
            const {'kind': 'missing'},
            rollbackLoggedOutSessionId: rollbackId,
          );
          continue;
        }
        if (credential.credentialGeneration != 1) {
          reply = await _activationEvidence(
            const {'kind': 'conflicting_owner'},
          );
          continue;
        }
        reply = await _activationEvidence({
          'kind': 'credential_verified',
          'credential_ref': credential.credentialRef,
          'credential_generation': credential.credentialGeneration,
        });
        continue;
      }

      if (phase == 'bind_namespace') {
        final credential = await _activationCredential(authorityState);
        if (credential == null) {
          reply = await _activationEvidence(
            const {'kind': 'missing'},
            rollbackLoggedOutSessionId: rollbackId,
          );
          continue;
        }
        if (credential.transitionId != transitionId) {
          reply = await _activationEvidence(
            const {'kind': 'conflicting_owner'},
          );
          continue;
        }
        if (!await saveIdentityNamespace(credential.userNamespace)) {
          reply = await _activationEvidence(
            const {'kind': 'unconfirmable_boundary'},
          );
          continue;
        }
        reply = await _activationEvidence({
          'kind': 'namespace_verified',
          'user_namespace': credential.userNamespace,
        });
        continue;
      }

      if (phase == 'reconcile_account') {
        final credential = await _activationCredential(authorityState);
        final namespace = authorityState['user_namespace'];
        if (credential == null || namespace is! String) {
          reply = await _activationEvidence(
            const {'kind': 'missing'},
            rollbackLoggedOutSessionId: rollbackId,
          );
          continue;
        }
        if (credential.transitionId != transitionId ||
            credential.userNamespace != namespace) {
          reply = await _activationEvidence(
            const {'kind': 'conflicting_owner'},
          );
          continue;
        }
        if (!await saveIdentityNamespace(namespace)) {
          reply = await _activationEvidence(
            const {'kind': 'unconfirmable_boundary'},
          );
          continue;
        }
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.reconciling,
          participantId: await loadParticipantIdInBucket(
            NetworkPrefs.guestBucket,
          ),
          sessionId: sessionId,
          credentialRef: credential.credentialRef,
          credentialGeneration: credential.credentialGeneration,
        ));
        return;
      }

      if (phase == 'commit_ready') {
        if (!await _activationReadyPrerequisitesPresent(authorityState)) {
          reply = await _activationEvidence(
            const {'kind': 'missing'},
            rollbackLoggedOutSessionId: rollbackId,
          );
          continue;
        }
        reply = await _activationEvidence(
          const {'kind': 'ready_prerequisites_verified'},
        );
        continue;
      }

      if (phase == 'rollback_clear') {
        final cleared = await _clearActivationArtifacts(sessionId);
        reply = await _activationEvidence(
          {
            'kind':
                cleared ? 'rollback_clear_verified' : 'unconfirmable_boundary'
          },
          rollbackLoggedOutSessionId: rollbackId,
        );
        continue;
      }

      if (phase == 'rollback_commit') {
        reply = await _activationEvidence(
          const {'kind': 'rollback_commit_verified'},
          rollbackLoggedOutSessionId: rollbackId,
        );
        continue;
      }

      reply = await _activationEvidence(
        const {'kind': 'unconfirmable_boundary'},
      );
    }
  }

  Future<SessionCredential?> _activationCredential(
    Map<String, dynamic> authorityState,
  ) async {
    final credentialRef = authorityState['credential_ref'];
    final credentialGeneration = authorityState['credential_generation'];
    if (credentialRef is! String || credentialGeneration is! int) return null;
    return _tokenStore.readSessionCredential(
      sessionId: _string(authorityState['session_id'], 'activation.session_id'),
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
    );
  }

  Future<bool> _activationReadyPrerequisitesPresent(
    Map<String, dynamic> authorityState,
  ) async {
    final credential = await _activationCredential(authorityState);
    final namespace = authorityState['user_namespace'];
    final binding = authorityState['account_binding'];
    if (credential == null || namespace is! String || binding is! Map) {
      return false;
    }
    if (credential.userNamespace != namespace ||
        await loadIdentityNamespace() != namespace) {
      return false;
    }
    final account = Map<String, dynamic>.from(binding);
    final address = account['address'];
    if (address is! String || address.isEmpty) return false;
    return await loadParticipantIdInBucket(
          NetworkPrefs.bucketForAddress(address),
        ) !=
        null;
  }

  Future<bool> _clearActivationArtifacts(String sessionId) async {
    if (!await _tokenStore.clearSessionCredentials(sessionId)) return false;
    if (!await _guestFlag.clear()) return false;
    if (!await _clearReconcileMarker()) return false;
    if (!await clearGuestParticipantId()) return false;
    return clearIdentityNamespace();
  }

  Future<void> _restoreReadyAuthority(
    Map<String, dynamic> authorityState,
  ) async {
    final sessionId = _string(authorityState['session_id'], 'session_id');
    final credentialRef =
        _string(authorityState['credential_ref'], 'credential_ref');
    final credentialGeneration = _integer(
      authorityState['credential_generation'],
      'credential_generation',
    );
    final userNamespace =
        _string(authorityState['user_namespace'], 'user_namespace');
    final binding = _map(authorityState['account_binding'], 'account_binding');
    final accountId = _string(binding['account_id'], 'account_id');
    final address = _string(binding['address'], 'address');
    final credential = await _tokenStore.readSessionCredential(
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
    );
    if (credential == null) {
      final unavailable = Identity(
        epoch: state.epoch,
        phase: IdentityPhase.ready,
        accountId: accountId,
        address: address,
        sessionId: sessionId,
        credentialRef: credentialRef,
        credentialGeneration: credentialGeneration,
      );
      _publish(Identity(
        epoch: state.epoch + 1,
        phase: IdentityPhase.transitioning,
        sessionId: sessionId,
      ));
      await _logoutWithAuthority(unavailable, signalCompletion: false);
      return;
    }
    if (credential.userNamespace != userNamespace) {
      _publish(Identity(
        epoch: state.epoch + 1,
        phase: IdentityPhase.transitioning,
        sessionId: sessionId,
      ));
      await _authorityTerminalReset('ready_credential_owner_mismatch');
      return;
    }
    if (!await saveIdentityNamespace(userNamespace)) {
      throw StateError('Ready session namespace could not be restored');
    }
    final bucket = NetworkPrefs.bucketForAddress(address);
    final participantId = await loadParticipantIdInBucket(bucket);
    if (participantId == null) {
      throw StateError('Ready session participant binding is unavailable');
    }
    _publish(Identity(
      epoch: state.epoch + 1,
      phase: IdentityPhase.ready,
      participantId: participantId,
      accountId: accountId,
      address: address,
      provisionedSeasonId: await _readProvisionedSeason(bucket),
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
    ));
  }

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

        if (_sessionAuthority != null) {
          return _completeAuthorityLogin(session, current);
        }

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

  Future<bool> _completeAuthorityLogin(
    AuthSession session,
    Identity current,
  ) async {
    final participantId = session.participant.id;
    final userNamespace =
        normalizeIdentityHash(session.participant.identityHash);
    if (userNamespace == null) {
      throw StateError('Authenticated session has no stable user namespace');
    }
    if (current.isAuthenticated && current.participantId == participantId) {
      final sessionId = _requiredAuthorityField(current.sessionId, 'session');
      final currentRef = _requiredAuthorityField(
          current.credentialRef, 'credential reference');
      final currentGeneration = current.credentialGeneration;
      if (currentGeneration == null || currentGeneration <= 0) {
        throw StateError('Ready identity has no credential generation');
      }
      final nextRef = _newAuthorityId('renewal');
      final next = SessionCredential(
        sessionId: sessionId,
        credentialRef: nextRef,
        credentialGeneration: currentGeneration + 1,
        token: session.token,
        userNamespace: userNamespace,
      );
      final credentialWritten = await _tokenStore.writeSessionCredential(next);
      if (!credentialWritten) {
        throw StateError('Renewed credential could not be verified');
      }
      final reply = await _authorityCommand({
        'command': 'renew_credential',
        'expected': _authorityRevision,
        'session_id': sessionId,
        'expected_credential_ref': currentRef,
        'expected_credential_generation': currentGeneration,
        'next_credential_ref': nextRef,
      });
      final ready = _replyState(reply, expectedKind: 'ready');
      final old = await _tokenStore.readSessionCredential(
        sessionId: sessionId,
        credentialRef: currentRef,
        credentialGeneration: currentGeneration,
      );
      if (old != null) await _tokenStore.clearSessionCredential(old);
      _publish(current.copyWith(
        credentialRef: _string(ready['credential_ref'], 'ready.credential_ref'),
        credentialGeneration:
            _integer(ready['credential_generation'], 'credential_generation'),
      ));
      return true;
    }

    if (current.isAuthenticated) {
      _retired = true;
      unawaited(_logoutStoredTokenBestEffort());
      unawaited(_logoutBestEffort(session.token));
      await _terminalReset(reason: 'different_participant_login');
      return false;
    }

    final epoch = current.epoch + 1;
    _publish(Identity(
      epoch: epoch,
      phase: IdentityPhase.transitioning,
      sessionId: current.sessionId,
    ));
    final sessionId = _newAuthorityId('session');
    final transitionId = _newAuthorityId('transition');
    final credentialRef = _newAuthorityId('credential');
    await _authorityCommand({
      'command': 'begin_activation',
      'expected': _authorityRevision,
      'session_id': sessionId,
      'transition_id': transitionId,
    });
    final credential = SessionCredential(
      sessionId: sessionId,
      transitionId: transitionId,
      credentialRef: credentialRef,
      credentialGeneration: 1,
      token: session.token,
      userNamespace: userNamespace,
    );
    if (!await _tokenStore.writeSessionCredential(credential)) {
      await _activationEvidence(const {'kind': 'unconfirmable_boundary'});
      throw StateError('Activation credential could not be verified');
    }
    await _activationEvidence({
      'kind': 'credential_verified',
      'credential_ref': credentialRef,
      'credential_generation': 1,
    });
    if (!await saveIdentityNamespace(userNamespace)) {
      await _activationEvidence(const {'kind': 'unconfirmable_boundary'});
      throw StateError('Activation namespace could not be verified');
    }
    await _activationEvidence({
      'kind': 'namespace_verified',
      'user_namespace': userNamespace,
    });

    await _writeReconcileMarker();
    await stageParticipantIdInGuestBucket(participantId);
    await _guestFlag.clear();
    await _suspendNode();
    _publish(Identity(
      epoch: epoch,
      phase: IdentityPhase.reconciling,
      participantId: participantId,
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: 1,
    ));
    return true;
  }

  Future<Map<String, dynamic>> _activationEvidence(
    Map<String, dynamic> evidence, {
    String? rollbackLoggedOutSessionId,
  }) =>
      _authorityCommand({
        'command': 'recover_activation',
        'expected': _authorityRevision,
        'evidence': evidence,
        'rollback_logged_out_session_id': rollbackLoggedOutSessionId,
      });

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
        String? guestSessionId;
        if (_sessionAuthority != null) {
          guestSessionId = _newAuthorityId('guest');
          final reply = await _authorityCommand({
            'command': 'update_logged_out',
            'expected': _authorityRevision,
            'successor_logged_out_session_id': guestSessionId,
            'mode': 'guest',
            'network': null,
          });
          final loggedOut = _replyState(reply, expectedKind: 'logged_out');
          if (loggedOut['mode'] != 'guest' ||
              loggedOut['session_id'] != guestSessionId) {
            throw StateError('Guest session authority was not committed');
          }
        }
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.guest,
          sessionId: guestSessionId,
        ));
      });

  /// Commits the selected network in the installation-wide journal before
  /// ending this process. Account-scoped data is retained for the next launch.
  Future<void> changeNetwork(String network) => _transition(() async {
        if (_sessionAuthority == null) {
          throw StateError('Network change requires session authority');
        }

        final current = state;
        _publish(Identity(
          epoch: current.epoch + 1,
          phase: IdentityPhase.transitioning,
          sessionId: current.sessionId,
        ));

        while (true) {
          final reply = await _authorityCommand({'command': 'read_record'});
          final authorityState = _replyStateFromRecord(reply);
          final kind = authorityState['kind'];

          if (kind == 'terminal_reset_required') {
            await _authorityTerminalReset(
              authorityState['reason'] is String
                  ? authorityState['reason'] as String
                  : 'session_authority_terminal',
            );
            return;
          }

          if (kind == 'activating') {
            final rollbackId =
                authorityState['rollback_logged_out_session_id'] as String? ??
                    _newAuthorityId('rollback');
            final cancelled = await _activationEvidence(
              const {'kind': 'explicit_cancellation'},
              rollbackLoggedOutSessionId: rollbackId,
            );
            await _restoreActivatingAuthority(cancelled);
            if (_retired) return;
            continue;
          }

          if (kind == 'retiring') {
            if (!await _signOutFence.raise()) {
              await _authorityTerminalReset('signout_fence_unconfirmable');
              return;
            }
            final completed = await _repairAuthorityRetirement(reply);
            if (completed == null) {
              await _authorityTerminalReset('retirement_repair_failed');
              return;
            }
            await _publishAuthorityLoggedOut(
              _replyState(completed, expectedKind: 'logged_out'),
              signalCompletion: false,
            );
            continue;
          }

          if (kind == 'ready') {
            if (!current.isAuthenticated ||
                current.sessionId != authorityState['session_id']) {
              await _authorityTerminalReset('network_change_owner_mismatch');
              return;
            }
            if (!await _logoutWithAuthority(
              current,
              signalCompletion: false,
              successorNetwork: network,
            )) {
              return;
            }
            _retired = true;
            await _terminatePreservingData(reason: 'network_change');
            return;
          }

          if (kind == 'logged_out') {
            final mode = _string(authorityState['mode'], 'logged_out.mode');
            if (mode != 'signed_out' && mode != 'guest') {
              throw StateError('Unknown logged-out mode: $mode');
            }
            final successorSessionId = _newAuthorityId('successor');
            final updated = await _authorityCommand({
              'command': 'update_logged_out',
              'expected': _authorityRevision,
              'successor_logged_out_session_id': successorSessionId,
              'mode': mode,
              'network': network,
            });
            final loggedOut = _replyState(
              updated,
              expectedKind: 'logged_out',
            );
            if (loggedOut['session_id'] != successorSessionId ||
                loggedOut['mode'] != mode ||
                _replyNetwork(updated) != network) {
              await _authorityTerminalReset('network_change_commit_mismatch');
              return;
            }
            await NetworkPrefs.adoptAuthorityNetwork(network);
            _publish(Identity(
              epoch: state.epoch,
              phase: mode == 'guest'
                  ? IdentityPhase.guest
                  : IdentityPhase.unauthenticated,
              sessionId: successorSessionId,
            ));
            _retired = true;
            await _terminatePreservingData(reason: 'network_change');
            return;
          }

          throw StateError('Network change cannot start from $kind');
        }
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

        if (_sessionAuthority != null) {
          return _logoutWithAuthority(current);
        }

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

        // Mirror a cold boot with no session. Retained account data remains on
        // disk but is not published as logged-out signing authority.
        _publish(Identity(
          epoch: epoch,
          phase: IdentityPhase.unauthenticated,
        ));
        _onSignOutCompleted?.call();
        return true;
      }, whenRetired: () => false);

  Future<bool> _logoutWithAuthority(
    Identity current, {
    bool signalCompletion = true,
    String? successorNetwork,
  }) async {
    final sessionId = _requiredAuthorityField(current.sessionId, 'session');
    final credentialRef =
        _requiredAuthorityField(current.credentialRef, 'credential reference');
    final credentialGeneration = current.credentialGeneration;
    if (credentialGeneration == null || credentialGeneration <= 0) {
      throw StateError('Ready identity has no credential generation');
    }
    final credential = await _tokenStore.readSessionCredential(
      sessionId: sessionId,
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
    );
    unawaited(_logoutBestEffort(credential?.token));

    final successorSessionId = _newAuthorityId('successor');
    final transitionId = _newAuthorityId('retirement');
    final entry = await _authorityCommand({
      'command': 'enter_retirement',
      'expected': _authorityRevision,
      'session_id': sessionId,
      'successor_logged_out_session_id': successorSessionId,
      'successor_network': successorNetwork,
      'transition_id': transitionId,
    });
    final enteredState = _map(
      _map(entry['record'], 'record')['state'],
      'record.state',
    );
    if (enteredState['kind'] != 'retiring') {
      await _authorityTerminalReset('retirement_entry_failed');
      return false;
    }

    // Compatibility-only crash marker. The Rust Ready -> Retiring CAS is the
    // authority boundary; this fence remains until the old path is retired.
    if (!await _signOutFence.raise()) {
      await _authorityTerminalReset('signout_fence_unconfirmable');
      return false;
    }
    final completed = await _repairAuthorityRetirement(entry);
    if (completed == null) {
      await _authorityTerminalReset('retirement_repair_failed');
      return false;
    }
    final loggedOut = _replyState(completed, expectedKind: 'logged_out');
    if (successorNetwork != null) {
      final committedNetwork = _replyNetwork(completed);
      if (committedNetwork != successorNetwork) {
        await _authorityTerminalReset('network_change_commit_mismatch');
        return false;
      }
      await NetworkPrefs.adoptAuthorityNetwork(committedNetwork);
    }
    await _publishAuthorityLoggedOut(
      loggedOut,
      signalCompletion: signalCompletion,
    );
    return true;
  }

  Future<Map<String, dynamic>?> _repairAuthorityRetirement(
    Map<String, dynamic> initialResponse,
  ) async {
    final authority = _sessionAuthority;
    if (authority == null) {
      throw StateError('Session authority is not configured');
    }
    final response = await RetirementRepairScope(
      authority: authority,
      tokenStore: _tokenStore,
      guestFlag: _guestFlag,
      revokeNativeAdmission: _rotateNativeGeneration,
      clearWebSessionData: _clearWebSessionData,
      retireRuntimeAuthority: _retireRuntimeAuthority,
    ).repair(initialResponse);
    if (response == null) return null;
    _adoptAuthorityReply(response);
    _replyState(response, expectedKind: 'logged_out');
    return response;
  }

  Future<void> _publishAuthorityLoggedOut(
    Map<String, dynamic> loggedOut, {
    required bool signalCompletion,
  }) async {
    try {
      await _resetSessionScopedProcessState?.call();
    } catch (error) {
      _log.warn('Could not clear retired process caches: $error');
    }
    try {
      if (!await _clearSessionNotifications()) {
        _log.warn('Native session-notification clear reported failure');
      }
    } catch (error) {
      _log.warn('Could not clear session notifications: $error');
    }
    try {
      if (!await _signOutFence.lower()) {
        _log.warn('Could not lower the compatibility sign-out fence');
      }
    } catch (error) {
      _log.warn('Could not lower the compatibility sign-out fence: $error');
    }
    _publish(Identity(
      epoch: state.epoch,
      phase: loggedOut['mode'] == 'guest'
          ? IdentityPhase.guest
          : IdentityPhase.unauthenticated,
      sessionId: _string(loggedOut['session_id'], 'logged_out.session_id'),
    ));
    if (signalCompletion) _onSignOutCompleted?.call();
  }

  Future<void> _authorityTerminalReset(String reason) async {
    _retired = true;
    await _terminalReset(reason: reason);
  }

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
  Future<bool> _clearSessionScopedState() =>
      clearCompatibilitySessionAuthority(_guestFlag);

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

  Future<String?> _readIdentityToken(Identity identity) =>
      identity.sessionId == null
          ? _tokenStore.read()
          : _tokenStore.readForIdentity(identity);

  /// Checks a reported 401 against the endpoint that owns mobile sessions.
  /// A transient failure to perform that check is not evidence that the
  /// credential is invalid, so it must preserve the current identity.
  Future<_SessionValidation> _validateSessionCredential(
    Identity identity,
    AuthCredentialLease credential,
  ) async {
    try {
      final session = await _repository.confirmBearerSession(credential);
      final participantId = identity.participantId;
      if (participantId != null && session.participant.id != participantId) {
        _log.warn(
          'Session authority resolved the current credential to participant '
          '${session.participant.id}, expected $participantId',
        );
        return _SessionValidation.ownerMismatch;
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
    if (_retired || !mounted || !credential.matchesIdentity(state)) return;
    final identity = state;

    // A stray auth-required request outside an authenticated identity
    // invalidates only that exact token; it is not a session replacement.
    if (!identity.isAuthenticated) {
      await _transition(() async {
        if (!state.sameScopeAs(identity)) return;
        final currentToken = await _readIdentityToken(identity);
        if (!state.sameScopeAs(identity) || currentToken != credential.token) {
          return;
        }
        await _tokenStore.clear();
      }, whenRetired: () {});
      return;
    }

    final currentToken = await _readIdentityToken(identity);
    if (_retired ||
        !mounted ||
        !state.sameScopeAs(identity) ||
        currentToken != credential.token) {
      _log.warn('Ignoring 401 for a credential that is no longer current');
      return;
    }

    final validation = await _validateSessionCredential(identity, credential);
    if (validation == _SessionValidation.valid) {
      _log.warn(
        'Ignoring 401 because the session authority still accepts the '
        'current credential',
      );
      return;
    }
    if (validation == _SessionValidation.unavailable) return;

    if (_sessionAuthority != null) {
      final retired = await _confirmAuthorityCredentialRejection(
        identity: identity,
        credential: credential,
        evidence: validation == _SessionValidation.ownerMismatch
            ? 'owner_mismatch'
            : 'definitive_rejection',
      );
      if (!retired) {
        _log.warn('Ignoring 401 for a credential that is no longer current');
      }
      return;
    }

    final loggedOut = await _logout(
      expectedIdentity: identity,
      expectedToken: credential.token,
      reason: 'session_expired',
    );
    if (!loggedOut) {
      _log.warn('Ignoring 401 for a credential that is no longer current');
    }
  }

  Future<bool> _confirmAuthorityCredentialRejection({
    required Identity identity,
    required AuthCredentialLease credential,
    required String evidence,
  }) =>
      _transition(() async {
        if (!state.sameScopeAs(identity) ||
            !credential.matchesIdentity(state) ||
            await _readIdentityToken(identity) != credential.token) {
          return false;
        }
        final sessionId = credential.sessionId;
        final credentialRef = credential.credentialRef;
        final credentialGeneration = credential.credentialGeneration;
        if (credentialGeneration <= 0) {
          throw StateError('Credential lease has no generation');
        }
        _publish(Identity(
          epoch: identity.epoch + 1,
          phase: IdentityPhase.transitioning,
        ));
        final reply = await _authorityCommand({
          'command': 'confirm_credential',
          'expected': _authorityRevision,
          'session_id': sessionId,
          'credential_ref': credentialRef,
          'credential_generation': credentialGeneration,
          'evidence': evidence,
          'successor_logged_out_session_id': _newAuthorityId('successor'),
          'transition_id': _newAuthorityId('retirement'),
        });
        final record = _map(reply['record'], 'record');
        final authorityState = _map(record['state'], 'record.state');
        if (authorityState['kind'] == 'ready') {
          await _restoreReadyAuthority(authorityState);
          return false;
        }
        if (authorityState['kind'] != 'retiring') {
          await _authorityTerminalReset('credential_retirement_failed');
          return false;
        }
        if (!await _signOutFence.raise()) {
          await _authorityTerminalReset('signout_fence_unconfirmable');
          return false;
        }
        final completed = await _repairAuthorityRetirement(reply);
        if (completed == null) {
          await _authorityTerminalReset('retirement_repair_failed');
          return false;
        }
        await _publishAuthorityLoggedOut(
          _replyState(completed, expectedKind: 'logged_out'),
          signalCompletion: true,
        );
        return true;
      }, whenRetired: () => false);

  /// Repairs an authenticated identity whose credential disappeared before a
  /// request could be sent. A token written since the caller's read wins.
  Future<void> onCredentialMissing({required int epoch}) async {
    if (_retired || !mounted) return;
    final identity = state;
    if (identity.epoch != epoch || !identity.isAuthenticated) return;
    if (_sessionAuthority != null) {
      await logout(expectedIdentity: identity);
      return;
    }
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
    int? provisionedSeasonId,
  }) =>
      _transition(() async {
        if (state.epoch != epoch || state.phase != IdentityPhase.reconciling) {
          _log.warn('Discarding stale reconcile result '
              '(epoch $epoch vs ${state.epoch}, phase ${state.phase.name})');
          return false;
        }
        final retainedReadyAuthority = _sessionAuthority != null &&
            state.sessionId != null &&
            state.credentialRef != null &&
            state.credentialGeneration != null &&
            state.accountId == accountId &&
            state.address == address;
        if (_sessionAuthority != null && !retainedReadyAuthority) {
          await _activationEvidence({
            'kind': 'account_verified',
            'account_binding': {
              'account_id': accountId,
              'address': address,
            },
          });
        }
        final bucket = NetworkPrefs.bucketForAddress(address);
        await _writeProvisionedSeason(bucket, provisionedSeasonId);
        // Persist the one-time legacy ownership migration before clearing the
        // recovery marker. A crash after the marker is cleared may restore
        // directly to ready only when this proof and the bucket owner id both
        // exist.
        await _writeLifecycleOwnershipConfirmed(bucket);
        await _clearReconcileMarker();
        Map<String, dynamic>? ready;
        if (_sessionAuthority != null && !retainedReadyAuthority) {
          final reply = await _activationEvidence(
            const {'kind': 'ready_prerequisites_verified'},
          );
          ready = _replyState(reply, expectedKind: 'ready');
          final binding = _map(ready['account_binding'], 'account_binding');
          if (binding['account_id'] != accountId ||
              binding['address'] != address) {
            throw StateError('Ready authority returned a different account');
          }
        }
        // FIXME(follow-up): Pass clearProvisionedSeasonId when the response is
        // null; copyWith otherwise retains the old baseline and repeats the
        // rollover reconcile.
        _publish(state.copyWith(
          phase: IdentityPhase.ready,
          accountId: accountId,
          address: address,
          participantId: participantId,
          provisionedSeasonId: provisionedSeasonId,
          sessionId: ready?['session_id'] as String?,
          credentialRef: ready?['credential_ref'] as String?,
          credentialGeneration: ready?['credential_generation'] as int?,
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
  Future<void> beginSeasonRollover({
    required int activeSeasonId,
    Identity? expectedIdentity,
  }) =>
      _transition(() async {
        if (expectedIdentity != null && !state.sameScopeAs(expectedIdentity)) {
          return;
        }
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

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) throw StateError('Session authority $field is not a map');
  return Map<String, dynamic>.from(value);
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw StateError('Session authority $field is missing');
  }
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw StateError('Session authority $field is invalid');
  }
  return value;
}

String _requiredAuthorityField(String? value, String field) {
  if (value == null || value.isEmpty) {
    throw StateError('Identity has no $field authority');
  }
  return value;
}
