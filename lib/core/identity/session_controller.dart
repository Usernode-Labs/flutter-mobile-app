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
import 'package:crypto_mobile_app/core/identity/session_host.dart';
import 'package:crypto_mobile_app/core/identity/session_retirement_repair.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

final _log = LoggingService.instance.withTag('usernode/SessionController');

typedef SessionDataPreservingTermination = Future<void> Function({
  required String reason,
});

enum _SessionValidation { valid, invalid, ownerMismatch, unavailable }

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider = Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

/// Production bootstrap overrides this with the already-admitted process
/// authority so every consumer shares its resolved installation directory.
final sessionAuthorityGatewayProvider =
    Provider<SessionAuthorityGateway>((ref) => SessionAuthorityGateway());

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
      sessionAuthority: ref.watch(sessionAuthorityGatewayProvider),
      sessionHost: ref.watch(sessionHostLifecycleProvider),
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
    Future<bool> Function()? clearWebSessionData,
    Future<bool> Function()? clearSessionNotifications,
    SessionDataPreservingTermination? terminatePreservingData,
    required SessionAuthorityGateway sessionAuthority,
    required SessionHostLifecycle sessionHost,
    String Function(String kind)? newAuthorityId,
    RetireRuntimeAuthority? retireRuntimeAuthority,
  })  : _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _repository = repository,
        _clearWebSessionData =
            clearWebSessionData ?? _defaultClearWebSessionData,
        _clearSessionNotifications =
            clearSessionNotifications ?? _defaultClearSessionNotifications,
        _terminatePreservingData =
            terminatePreservingData ?? _defaultTerminatePreservingData,
        _sessionAuthority = sessionAuthority,
        _sessionHost = sessionHost,
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

  /// Clears the WKWebView/WebView cookie + storage jar backing the platform
  /// shell. A sign-out that left it in place would reload straight back into
  /// an authenticated page. Injectable for tests; the default crosses the
  /// native method channel.
  final Future<bool> Function() _clearWebSessionData;

  /// Removes notifications the retired session has already posted.
  final Future<bool> Function() _clearSessionNotifications;

  final SessionDataPreservingTermination _terminatePreservingData;
  final SessionAuthorityGateway _sessionAuthority;
  final SessionHostLifecycle _sessionHost;
  final String Function(String kind) _newAuthorityId;
  final RetireRuntimeAuthority? _retireRuntimeAuthority;
  Map<String, dynamic>? _authorityRevisionValue;

  static String _defaultNewAuthorityId(String kind) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return '$kind-${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  static Future<bool> _defaultClearWebSessionData() =>
      PlatformAlarmService.instance.clearWebSessionData();

  static Future<bool> _defaultClearSessionNotifications() =>
      PlatformAlarmService.instance.clearSessionNotifications();

  static Future<void> _defaultTerminatePreservingData({
    required String reason,
  }) =>
      AppResetService.instance.terminatePreservingData(reason: reason);

  Future<void>? _restoreFuture;
  Future<void> _queueTail = Future.value();
  final Queue<Future<void> Function()> _pendingTransitions = Queue();
  bool _transitionActive = false;

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
    final reply = await _sessionAuthority.command(request);
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
      return Future<T>.error(StateError('Session controller is disposed'));
    }

    if (!mounted) return retiredResult();
    final result = Completer<T>();

    Future<void> run() async {
      try {
        if (!mounted) {
          if (whenRetired != null) {
            result.complete(whenRetired());
          } else {
            result.completeError(StateError('Session controller is disposed'));
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
        await _restoreFromSessionAuthority();
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
      final completed = await _repairAuthorityRetirement(reply);
      final loggedOut = _replyState(completed, expectedKind: 'logged_out');
      await _reclaimRetiredSession(
        _string(authorityState['session_id'], 'retiring.session_id'),
      );
      _publishAuthorityLoggedOut(loggedOut);
      return;
    }
    if (kind == 'authority_recovery_required') {
      _publish(Identity(
        epoch: state.epoch + 1,
        phase: IdentityPhase.transitioning,
      ));
      throw StateError(
        'Session authority requires recovery: ${authorityState['reason']}',
      );
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
      if (kind == 'authority_recovery_required') {
        _publish(Identity(
          epoch: state.epoch + 1,
          phase: IdentityPhase.transitioning,
        ));
        throw StateError(
          'Session authority requires recovery: ${authorityState['reason']}',
        );
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
      await _logoutWithAuthority(
        unavailable,
        replaceHost: false,
      );
      return;
    }
    if (credential.userNamespace != userNamespace) {
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
      await _logoutWithAuthority(
        unavailable,
        replaceHost: false,
      );
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

  /// Accepts an authoritative authenticated session.
  ///
  /// Initial login and a renewed credential for the current participant are
  /// applied in place. A different participant retires the current session
  /// and activates from its fresh logged-out successor in the same process.
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

        final current = state;
        return _completeAuthorityLogin(session, current);
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
      _publish(Identity(
        epoch: current.epoch + 1,
        phase: IdentityPhase.transitioning,
        sessionId: current.sessionId,
      ));
      final successor = await _logoutWithAuthority(
        current,
      );
      if (!identical(successor, this)) {
        return successor.completeLogin(session);
      }
      return _completeAuthorityLogin(session, state);
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

  Future<void> continueAsGuest() => _transition(() async {
        final current = state;
        if (current.isAuthenticated) {
          _publish(Identity(
            epoch: current.epoch + 1,
            phase: IdentityPhase.transitioning,
            sessionId: current.sessionId,
          ));
          final successor = await _logoutWithAuthority(
            current,
          );
          if (!identical(successor, this)) {
            await successor.continueAsGuest();
            return;
          }
        } else {
          // Close signing/node gates before changing the logged-out
          // incarnation. Guest node admission remains disabled.
          _publish(Identity(
            epoch: current.epoch + 1,
            phase: IdentityPhase.transitioning,
            sessionId: current.sessionId,
          ));
        }

        await _tokenStore.clear();
        await _guestFlag.setGuest();
        await clearGuestParticipantId();
        await _clearReconcileMarker();
        final guestSessionId = _newAuthorityId('guest');
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
        _publish(Identity(
          epoch: state.epoch,
          phase: IdentityPhase.guest,
          sessionId: guestSessionId,
        ));
      });

  /// Commits the selected network in the installation-wide journal before
  /// ending this process. Account-scoped data is retained for the next launch.
  Future<void> changeNetwork(String network) => _transition(() async {
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

          if (kind == 'authority_recovery_required') {
            throw StateError(
              'Session authority requires recovery: '
              '${authorityState['reason']}',
            );
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
            continue;
          }

          if (kind == 'retiring') {
            final completed = await _repairAuthorityRetirement(reply);
            await _reclaimRetiredSession(
              _string(authorityState['session_id'], 'retiring.session_id'),
            );
            _publishAuthorityLoggedOut(
              _replyState(completed, expectedKind: 'logged_out'),
            );
            continue;
          }

          if (kind == 'ready') {
            if (!current.isAuthenticated ||
                current.sessionId != authorityState['session_id']) {
              throw StateError('Network change lost its exact session owner');
            }
            await _logoutWithAuthority(
              current,
              successorNetwork: network,
            );
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
              throw StateError('Network change committed a different owner');
            }
            await NetworkPrefs.adoptAuthorityNetwork(network);
            _publish(Identity(
              epoch: state.epoch,
              phase: mode == 'guest'
                  ? IdentityPhase.guest
                  : IdentityPhase.unauthenticated,
              sessionId: successorSessionId,
            ));
            await _terminatePreservingData(reason: 'network_change');
            return;
          }

          throw StateError('Network change cannot start from $kind');
        }
      });

  /// Voluntary sign-out. The one identity boundary that is NOT terminal.
  ///
  /// Voluntary sign-out retires the durable session while retaining
  /// account-scoped wallet data for an exact future reconciliation.
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
        await _logoutWithAuthority(current);
        return true;
      }, whenRetired: () => false);

  Future<SessionController> _logoutWithAuthority(
    Identity current, {
    String? successorNetwork,
    bool replaceHost = true,
  }) async {
    final sessionId = _requiredAuthorityField(current.sessionId, 'session');
    final credentialRef =
        _requiredAuthorityField(current.credentialRef, 'credential reference');
    final credentialGeneration = current.credentialGeneration;
    if (credentialGeneration == null || credentialGeneration <= 0) {
      throw StateError('Ready identity has no credential generation');
    }
    final successorSessionId = _newAuthorityId('successor');
    final transitionId = _newAuthorityId('retirement');
    late Map<String, dynamic> completed;

    Future<void> retire() async {
      final credential = await _tokenStore.readSessionCredential(
        sessionId: sessionId,
        credentialRef: credentialRef,
        credentialGeneration: credentialGeneration,
      );
      unawaited(_logoutBestEffort(credential?.token));

      final initial = await _authorityCommand({'command': 'read_record'});
      final authorityState = _replyStateFromRecord(initial);
      final kind = authorityState['kind'];
      if (kind == 'ready') {
        if (authorityState['session_id'] != sessionId) {
          throw StateError('Retirement lost its exact Ready owner');
        }
        completed = await _repairAuthorityRetirement(
          initial,
          successorLoggedOutSessionId: successorSessionId,
          successorNetwork: successorNetwork,
          transitionId: transitionId,
        );
      } else if (kind == 'retiring') {
        if (authorityState['session_id'] != sessionId ||
            authorityState['successor_logged_out_session_id'] !=
                successorSessionId ||
            authorityState['successor_network'] != successorNetwork ||
            authorityState['transition_id'] != transitionId) {
          throw StateError('A different retirement owns the journal');
        }
        completed = await _repairAuthorityRetirement(initial);
      } else if (kind == 'logged_out') {
        if (authorityState['session_id'] != successorSessionId) {
          throw StateError('A different logged-out successor owns the journal');
        }
        completed = initial;
      } else {
        throw StateError('Retirement cannot resume from $kind');
      }

      final loggedOut = _replyState(completed, expectedKind: 'logged_out');
      if (successorNetwork != null) {
        final committedNetwork = _replyNetwork(completed);
        if (committedNetwork != successorNetwork) {
          throw StateError('Network change committed a different network');
        }
        await NetworkPrefs.adoptAuthorityNetwork(committedNetwork);
      }
      await _reclaimRetiredSession(sessionId);
      if (!replaceHost) {
        _publishAuthorityLoggedOut(loggedOut);
      }
    }

    if (!replaceHost) {
      await retire();
      return this;
    }

    final successorContainer = await _sessionHost.replace(retire: retire);
    if (successorContainer == null) {
      _publishAuthorityLoggedOut(
        _replyState(completed, expectedKind: 'logged_out'),
      );
      return this;
    }
    return successorContainer.read(identityProvider.notifier);
  }

  Future<Map<String, dynamic>> _repairAuthorityRetirement(
    Map<String, dynamic> initialResponse, {
    String? successorLoggedOutSessionId,
    String? successorNetwork,
    String? transitionId,
  }) async {
    final response = await RetirementRepairScope(
      authority: _sessionAuthority,
      clearWebSessionData: _clearWebSessionData,
      retireRuntimeAuthority: _retireRuntimeAuthority,
    ).repair(
      initialResponse,
      successorLoggedOutSessionId: successorLoggedOutSessionId,
      successorNetwork: successorNetwork,
      transitionId: transitionId,
    );
    _adoptAuthorityReply(response);
    _replyState(response, expectedKind: 'logged_out');
    return response;
  }

  Future<void> _reclaimRetiredSession(String sessionId) async {
    try {
      if (!await _tokenStore.clearSessionCredentials(sessionId)) {
        _log.warn('Retired credential cleanup was not confirmed');
      }
    } catch (error) {
      _log.warn('Could not reclaim the retired credential: $error');
    }
    try {
      if (!await clearCompatibilitySessionAuthority(_guestFlag)) {
        _log.warn('Compatibility session cleanup was not confirmed');
      }
    } catch (error) {
      _log.warn('Could not reclaim compatibility session state: $error');
    }
    try {
      if (!await _clearSessionNotifications()) {
        _log.warn('Native session-notification clear reported failure');
      }
    } catch (error) {
      _log.warn('Could not clear session notifications: $error');
    }
  }

  void _publishAuthorityLoggedOut(Map<String, dynamic> loggedOut) {
    _publish(Identity(
      epoch: state.epoch,
      phase: loggedOut['mode'] == 'guest'
          ? IdentityPhase.guest
          : IdentityPhase.unauthenticated,
      sessionId: _string(loggedOut['session_id'], 'logged_out.session_id'),
    ));
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
      _tokenStore.readForIdentity(identity);

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
    if (!mounted || !credential.matchesIdentity(state)) return;
    final identity = state;

    final currentToken = await _readIdentityToken(identity);
    if (!mounted ||
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
        final reply = await _authorityCommand({
          'command': 'confirm_credential',
          'expected': _authorityRevision,
          'session_id': sessionId,
          'credential_ref': credentialRef,
          'credential_generation': credentialGeneration,
          'evidence': evidence,
        });
        final outcome = _map(reply['outcome'], 'outcome')['kind'];
        if (outcome == 'credential_confirmation_preserved' ||
            outcome == 'credential_confirmation_stale') {
          return false;
        }
        if (outcome != 'credential_confirmation_rejected') {
          throw StateError('Unknown credential confirmation outcome: $outcome');
        }
        final authorityState = _replyState(reply, expectedKind: 'ready');
        if (authorityState['session_id'] != sessionId) {
          return false;
        }
        _publish(Identity(
          epoch: identity.epoch + 1,
          phase: IdentityPhase.transitioning,
          sessionId: sessionId,
        ));
        await _logoutWithAuthority(identity);
        return true;
      }, whenRetired: () => false);

  /// Repairs an authenticated identity whose credential disappeared before a
  /// request could be sent. A token written since the caller's read wins.
  Future<void> onCredentialMissing({required int epoch}) async {
    if (!mounted) return;
    final identity = state;
    if (identity.epoch != epoch || !identity.isAuthenticated) return;
    await logout(expectedIdentity: identity);
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
        final retainedReadyAuthority = state.sessionId != null &&
            state.credentialRef != null &&
            state.credentialGeneration != null &&
            state.accountId == accountId &&
            state.address == address;
        if (!retainedReadyAuthority) {
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
        if (!retainedReadyAuthority) {
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
