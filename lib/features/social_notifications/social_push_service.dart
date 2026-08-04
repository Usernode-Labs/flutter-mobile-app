import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';

import 'social_push_api.dart';
import 'social_push_messaging.dart';
import 'social_push_payload.dart';
import 'social_push_store.dart';

typedef SocialPushUnauthorized = Future<void> Function(
  AuthCredentialLease credential,
);

class SocialPushSession {
  const SocialPushSession({
    required this.userId,
    required this.credential,
    required this.onUnauthorized,
  });

  final int userId;
  final AuthCredentialLease credential;
  final SocialPushUnauthorized onUnauthorized;

  bool sameCredentialAs(SocialPushSession other) =>
      userId == other.userId &&
      credential.epoch == other.credential.epoch &&
      credential.token == other.credential.token;

  @override
  String toString() => 'SocialPushSession('
      'userId: $userId, epoch: ${credential.epoch}, token: <redacted>)';
}

/// Process-lifetime owner of Firebase Messaging and Social registration.
///
/// Every mutation is serialized through one queue. Identity remains owned by
/// SessionController; a container-scoped adapter attaches only an immutable
/// ready-session snapshot and detaches it synchronously at identity boundaries.
class SocialPushService {
  SocialPushService({
    required SocialPushMessaging messaging,
    required SocialPushPersistence persistence,
    required SocialPushRegistrationApi api,
    required this.environment,
    required this.expectedFirebaseProjectId,
    required this.platform,
    DateTime Function()? now,
  })  : _messaging = messaging,
        _persistence = persistence,
        _api = api,
        _now = now ?? DateTime.now;

  static final SocialPushService instance = SocialPushService(
    messaging: FirebaseSocialPushMessaging(),
    persistence: SecureStorageSocialPushPersistence(),
    api: HttpSocialPushRegistrationApi(
      mobileApiBaseUrl: AppConfig.mobileApiBaseUrl,
      expectedEnvironment: AppConfig.pushEnvironment,
      expectedFirebaseProjectId: AppConfig.expectedFirebaseProjectId,
    ),
    environment: AppConfig.pushEnvironment,
    expectedFirebaseProjectId: AppConfig.expectedFirebaseProjectId,
    platform: defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : null,
  );

  final SocialPushMessaging _messaging;
  final SocialPushPersistence _persistence;
  final SocialPushRegistrationApi _api;
  final DateTime Function() _now;
  final String environment;
  final String expectedFirebaseProjectId;
  final String? platform;

  final StreamController<SocialPushState> _stateEvents =
      StreamController<SocialPushState>.broadcast(sync: true);
  final StreamController<void> _tapEvents =
      StreamController<void>.broadcast(sync: true);
  final StreamController<void> _foregroundEvents =
      StreamController<void>.broadcast(sync: true);

  Future<void>? _initialization;
  Future<void> _queueTail = Future<void>.value();
  StreamSubscription<Map<String, Object?>>? _openedSubscription;
  StreamSubscription<Map<String, Object?>>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;

  SocialPushRecord? _record;
  bool _recordPersisted = false;
  bool _available = false;
  bool _resetting = false;
  Object? _sessionOwner;
  SocialPushSession? _session;
  SocialPushSession? _cleanedSession;
  SocialPushSession? _registeredSession;
  String? _registeredProviderToken;
  SocialPushPermission? _registeredPermission;
  SocialPushPermission _permission = SocialPushPermission.notDetermined;
  SocialPushRegistrationStatus _registrationStatus =
      SocialPushRegistrationStatus.disabled;
  bool _deliveryActive = false;
  int _foregroundInvalidationRevision = 0;
  int _tapCaptureGeneration = 0;
  bool _tapCaptureBlocked = false;
  int? _providerRotationBoundaryGeneration;
  bool _providerTokenCleanupPending = false;
  SocialPushState? _lastEmittedState;

  Stream<SocialPushState> get stateEvents => _stateEvents.stream;
  Stream<void> get tapEvents => _tapEvents.stream;
  Stream<void> get foregroundEvents => _foregroundEvents.stream;
  bool get hasPendingTap => !_tapCaptureBlocked && _record?.pending != null;
  int get foregroundInvalidationRevision => _foregroundInvalidationRevision;

  SocialPushState get currentState => SocialPushState(
        enabled: _record?.optedIn ?? false,
        permission: _permission,
        registrationStatus: _registrationStatus,
        deliveryActive: _deliveryActive,
      );

  Future<void> initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    try {
      _record = await _persistence.load();
      if (_tapCaptureBlocked && _record!.pending != null) {
        _record = _record!.copyWith(clearPending: true);
      }
      final recordBeingSaved = _record!;
      await _persistence.save(recordBeingSaved);
      // A rotating account boundary can synchronously replace [_record]
      // while this first write is in flight. Only acknowledge the write when
      // it persisted the record that is still authoritative; otherwise the
      // queued boundary must rewrite its cleared record.
      _recordPersisted = identical(_record, recordBeingSaved);
    } catch (error) {
      _record = SocialPushRecord.fresh();
      _recordPersisted = false;
      _registrationStatus = SocialPushRegistrationStatus.error;
      await _disableUntrustedProviderState();
      _emitState();
      debugPrint(
        '[SocialPush] Local state unavailable (${error.runtimeType})',
      );
      return;
    }

    if (environment.isEmpty ||
        expectedFirebaseProjectId.isEmpty ||
        platform == null) {
      await _disableUntrustedProviderState();
      _registrationStatus = _record!.optedIn
          ? SocialPushRegistrationStatus.error
          : SocialPushRegistrationStatus.disabled;
      _emitState();
      return;
    }

    String? projectId;
    try {
      projectId = await _messaging.initialize();
    } catch (error) {
      _registrationStatus = _record!.optedIn
          ? SocialPushRegistrationStatus.error
          : SocialPushRegistrationStatus.disabled;
      debugPrint(
        '[SocialPush] Firebase unavailable (${error.runtimeType})',
      );
      _emitState();
      return;
    }
    if (projectId != expectedFirebaseProjectId) {
      await _disableInitializedProviderState();
      _registrationStatus = _record!.optedIn
          ? SocialPushRegistrationStatus.error
          : SocialPushRegistrationStatus.disabled;
      _emitState();
      return;
    }

    _available = true;
    _foregroundSubscription = _messaging.foregroundMessages.listen(
      (message) => _runDetached(
        _enqueue(() => _handleForegroundNow(message)),
        'foreground message',
      ),
      onError: (_, __) {},
    );
    _openedSubscription = _messaging.openedMessages.listen(
      (message) {
        final captureGeneration = _tapCaptureGeneration;
        _runDetached(
          _enqueue(() => _captureTapNow(message, captureGeneration)),
          'opened message',
        );
      },
      onError: (_, __) {},
    );
    _tokenSubscription = _messaging.tokenRefreshes.listen(
      (_) => reconcileBestEffort(),
      onError: (_, __) {},
    );

    var permissionReadFailed = false;
    try {
      _permission = await _messaging.getPermission();
    } catch (error) {
      permissionReadFailed = true;
      debugPrint(
        '[SocialPush] Could not read notification permission '
        '(${error.runtimeType})',
      );
    }
    try {
      final captureGeneration = _tapCaptureGeneration;
      final initialMessage = await _messaging.getInitialOpenedMessage();
      if (initialMessage != null) {
        await _enqueue(
          () => _captureTapNow(initialMessage, captureGeneration),
        );
      }
    } catch (error) {
      debugPrint(
        '[SocialPush] Could not read the launch notification '
        '(${error.runtimeType})',
      );
    }

    _registrationStatus = permissionReadFailed && _record!.optedIn
        ? SocialPushRegistrationStatus.error
        : _statusWithoutRegistration();
    _emitState();
  }

  Future<void> _disableUntrustedProviderState() async {
    if (platform == null) return;
    try {
      await _messaging.initialize();
    } catch (_) {
      return;
    }
    await _disableInitializedProviderState();
  }

  Future<bool> _disableInitializedProviderState() async {
    try {
      await _messaging.setAutoInitEnabled(false);
    } catch (_) {
      // A missing or mismatched configuration is never allowed to register;
      // cleanup is best effort because native Firebase may itself be invalid.
    }
    try {
      await _messaging.deleteToken();
      return true;
    } catch (_) {
      // Try both shutdown mechanisms independently: either one may still work.
      return false;
    }
  }

  /// Attaches the exact ready bearer owned by the active provider container.
  /// Calling this with a renewed same-user bearer simply queues another PUT.
  void attachSession(Object owner, SocialPushSession session) {
    final previousSession = _session;
    final crossUserBoundary =
        previousSession != null && previousSession.userId != session.userId;
    final boundaryGeneration =
        crossUserBoundary ? _beginRotatingAccountBoundary() : null;
    final unchanged =
        _sessionOwner == owner && _session?.sameCredentialAs(session) == true;
    _sessionOwner = owner;
    _session = session;
    if (_cleanedSession?.sameCredentialAs(session) != true) {
      _cleanedSession = null;
    }
    if (_registeredSession?.sameCredentialAs(session) != true) {
      _clearRegisteredSignature();
    }
    _resetting = false;
    if (boundaryGeneration != null) {
      _deliveryActive = false;
      _registrationStatus = _statusWithoutRegistration();
      _emitState();
      _scheduleAccountBoundary(boundaryGeneration);
    } else if (!unchanged) {
      reconcileBestEffort();
    }
  }

  /// Closes the bearer gate immediately. Provider-token cleanup remains on the
  /// same serialized queue, so an already-running old PUT settles before the
  /// token is rotated and a replacement session can register.
  void detachSession(
    Object owner, {
    required bool rotateProviderToken,
    bool ifAlreadyUnbound = false,
  }) {
    if (_sessionOwner != owner &&
        !(_sessionOwner == null && ifAlreadyUnbound)) {
      return;
    }
    final previousSession = _session;
    final boundaryGeneration =
        rotateProviderToken ? _beginRotatingAccountBoundary() : null;
    _sessionOwner = null;
    _session = null;
    _cleanedSession = null;
    _clearRegisteredSignature();
    _deliveryActive = false;
    _registrationStatus = _statusWithoutRegistration();
    _emitState();
    if (boundaryGeneration != null) {
      _scheduleAccountBoundary(
        boundaryGeneration,
        sessionToUnregister: previousSession,
      );
    }
  }

  Future<SocialPushState> refreshState() async {
    await initialize();
    await _enqueue(_reconcileNow);
    return currentState;
  }

  Future<SocialPushState> setEnabled(bool enabled) async {
    await initialize();
    await _enqueue(() => _setEnabledNow(enabled));
    return currentState;
  }

  Future<void> reconcile() async {
    await initialize();
    await _enqueue(_reconcileNow);
  }

  void reconcileBestEffort() {
    _runDetached(reconcile(), 'reconcile');
  }

  Future<int?> claimPendingNotification({required int userId}) async {
    await initialize();
    return _enqueue(() async {
      if (_tapCaptureBlocked) return null;
      final record = _record!;
      final pending = record.pending;
      if (pending == null) return null;
      if (pending.isExpired(_now())) {
        await _replaceRecord(record.copyWith(clearPending: true));
        return null;
      }
      final expectedBinding = socialPushRecipientBinding(
        installationId: record.installationId,
        userId: userId,
        environment: environment,
      );
      if (pending.recipientBinding != expectedBinding) {
        await _replaceRecord(record.copyWith(clearPending: true));
        return null;
      }
      return pending.notificationId;
    });
  }

  Future<bool> acknowledgePendingNotification({
    required int userId,
    required int notificationId,
  }) async {
    await initialize();
    return _enqueue(() async {
      if (_tapCaptureBlocked) return false;
      final record = _record!;
      final pending = record.pending;
      if (pending == null || pending.notificationId != notificationId) {
        return false;
      }
      final expectedBinding = socialPushRecipientBinding(
        installationId: record.installationId,
        userId: userId,
        environment: environment,
      );
      if (pending.recipientBinding != expectedBinding) return false;
      await _replaceRecord(record.copyWith(clearPending: true));
      return true;
    });
  }

  /// Runs before SharedPreferences is cleared by an in-process app reset.
  /// The new runtime persists this fresh installation before reconciling.
  Future<void> resetForAppReset() async {
    final previousSession = _session;
    _fenceTapCaptureAtAccountBoundary();
    _sessionOwner = null;
    _session = null;
    _clearRegisteredSignature();
    _resetting = true;
    var installedFreshState = false;
    try {
      await initialize();
      await _enqueue(() async {
        try {
          await _rotateProviderTokenNow();
          if (previousSession != null) {
            await _unregisterNow(previousSession);
          }
          await _persistence.clear();
        } finally {
          _installFreshResetState();
          installedFreshState = true;
        }
      });
    } finally {
      if (!installedFreshState) {
        _installFreshResetState();
      }
    }
  }

  void _installFreshResetState() {
    _record = SocialPushRecord.fresh();
    _recordPersisted = false;
    _cleanedSession = null;
    _permission = SocialPushPermission.notDetermined;
    _registrationStatus = SocialPushRegistrationStatus.disabled;
    _deliveryActive = false;
    _tapCaptureBlocked = true;
    _providerRotationBoundaryGeneration = null;
    _emitState();
  }

  Future<void> _setEnabledNow(bool enabled) async {
    if (_resetting) return;
    await _ensureRecordPersisted();
    final record = _record!;
    if (!enabled) {
      final session = _session;
      _cleanedSession = null;
      await _replaceRecord(record.copyWith(
        optedIn: false,
        clearPending: true,
      ));
      _registrationStatus = SocialPushRegistrationStatus.disabling;
      _deliveryActive = false;
      _emitState();
      await _rotateProviderTokenNow();
      if (session != null && _session?.sameCredentialAs(session) == true) {
        if (await _unregisterNow(session)) _cleanedSession = session;
      }
      _registrationStatus = SocialPushRegistrationStatus.disabled;
      _emitState();
      return;
    }

    _cleanedSession = null;
    if (!record.optedIn) {
      await _replaceRecord(record.copyWith(optedIn: true));
    }
    if (!_available) {
      _registrationStatus = SocialPushRegistrationStatus.error;
      _emitState();
      return;
    }
    try {
      _permission = await _messaging.requestPermission();
    } catch (_) {
      _registrationStatus = SocialPushRegistrationStatus.error;
      _emitState();
      return;
    }
    await _reconcileNow(refreshPermission: false);
  }

  Future<void> _reconcileNow({bool refreshPermission = true}) async {
    if (_resetting || _providerRotationBoundaryGeneration != null) return;
    await _ensureRecordPersisted();
    if (_session != null && _tapCaptureBlocked) {
      _tapCaptureBlocked = false;
    }
    final record = _record!;
    if (!_available) {
      _registrationStatus = record.optedIn
          ? SocialPushRegistrationStatus.error
          : SocialPushRegistrationStatus.disabled;
      _deliveryActive = false;
      _emitState();
      return;
    }

    if (refreshPermission) {
      try {
        _permission = await _messaging.getPermission();
      } catch (_) {
        _registrationStatus = SocialPushRegistrationStatus.error;
        _deliveryActive = false;
        _emitState();
        return;
      }
    }

    if (!record.optedIn) {
      _registrationStatus = SocialPushRegistrationStatus.disabled;
      _deliveryActive = false;
      _emitState();
      final session = _session;
      await _rotateProviderTokenNow(updateStatus: false);
      if (record.mutationRevision > 0 &&
          session != null &&
          _cleanedSession?.sameCredentialAs(session) != true &&
          await _unregisterNow(session)) {
        _cleanedSession = session;
      }
      return;
    }
    if (_permission == SocialPushPermission.denied) {
      _registrationStatus = SocialPushRegistrationStatus.permissionDenied;
      _deliveryActive = false;
      _emitState();
      final session = _session;
      await _rotateProviderTokenNow(updateStatus: false);
      if (record.mutationRevision > 0 &&
          session != null &&
          _session?.sameCredentialAs(session) == true &&
          _cleanedSession?.sameCredentialAs(session) != true &&
          await _unregisterNow(session)) {
        _cleanedSession = session;
      }
      return;
    }
    if (_permission == SocialPushPermission.notDetermined) {
      // Never show the OS prompt outside setEnabled(true)'s user gesture.
      _registrationStatus = SocialPushRegistrationStatus.unregistered;
      _deliveryActive = false;
      _emitState();
      await _messaging.setAutoInitEnabled(false);
      return;
    }

    final session = _session;
    if (session == null) {
      _registrationStatus = SocialPushRegistrationStatus.unregistered;
      _deliveryActive = false;
      _emitState();
      if (_providerTokenCleanupPending) {
        await _rotateProviderTokenNow(updateStatus: false);
      } else {
        await _messaging.setAutoInitEnabled(false);
      }
      return;
    }

    try {
      await _messaging.setAutoInitEnabled(true);
      if (platform == 'ios' && await _messaging.getApnsToken() == null) {
        _registrationStatus = SocialPushRegistrationStatus.unregistered;
        _deliveryActive = false;
        _emitState();
        return;
      }
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _registrationStatus = SocialPushRegistrationStatus.unregistered;
        _deliveryActive = false;
        _emitState();
        return;
      }
      if (_session?.sameCredentialAs(session) != true) return;
      final signatureMatches =
          _registeredSession?.sameCredentialAs(session) == true &&
              _registeredProviderToken == token &&
              _registeredPermission == _permission;
      final status = await _api.getStatus(
        bearer: session.credential.token,
        installationId: _record!.installationId,
      );
      if (_session?.sameCredentialAs(session) != true) return;
      if (status.registered && signatureMatches) {
        _registrationStatus = SocialPushRegistrationStatus.registered;
        _deliveryActive = status.deliveryActive;
        _emitState();
        return;
      }
      _registrationStatus = SocialPushRegistrationStatus.registering;
      _deliveryActive = false;
      _emitState();
      final reply = await _registerNow(session, token, retryConflict: true);
      if (reply == null || _session?.sameCredentialAs(session) != true) return;
      _registeredSession = session;
      _registeredProviderToken = token;
      _registeredPermission = _permission;
      _cleanedSession = null;
      _providerTokenCleanupPending = false;
      _registrationStatus = SocialPushRegistrationStatus.registered;
      _deliveryActive = reply.deliveryActive;
    } on SocialPushApiException catch (error) {
      if (error.statusCode == 401 &&
          _session?.sameCredentialAs(session) == true) {
        _runDetached(
          session.onUnauthorized(session.credential),
          'unauthorized session handling',
        );
      }
      if (_session?.sameCredentialAs(session) == true) {
        _clearRegisteredSignature();
        _registrationStatus = SocialPushRegistrationStatus.error;
        _deliveryActive = false;
      }
    } catch (_) {
      if (_session?.sameCredentialAs(session) == true) {
        _clearRegisteredSignature();
        _registrationStatus = SocialPushRegistrationStatus.error;
        _deliveryActive = false;
      }
    }
    _emitState();
  }

  Future<SocialPushRegistrationReply?> _registerNow(
    SocialPushSession session,
    String token, {
    required bool retryConflict,
  }) async {
    final revision = await _nextMutationRevision();
    try {
      return await _api.register(
        bearer: session.credential.token,
        installationId: _record!.installationId,
        registrationToken: token,
        platform: platform!,
        permissionStatus: _permission.wireName,
        mutationRevision: revision,
      );
    } on SocialPushApiException catch (error) {
      if (retryConflict &&
          error.statusCode == 409 &&
          await _adoptLatestRevision(error.latestMutationRevision)) {
        return _registerNow(session, token, retryConflict: false);
      }
      rethrow;
    }
  }

  Future<bool> _unregisterNow(SocialPushSession session) async {
    try {
      await _unregisterAttempt(session, retryConflict: true);
      return true;
    } on SocialPushApiException catch (error) {
      if (error.statusCode == 401 &&
          _session?.sameCredentialAs(session) == true) {
        _runDetached(
          session.onUnauthorized(session.credential),
          'unauthorized session handling',
        );
      }
      // Local opt-out and provider-token deletion are authoritative even when
      // backend cleanup is temporarily unavailable.
      return false;
    } catch (_) {
      // Best effort for the same reason.
      return false;
    }
  }

  Future<void> _unregisterAttempt(
    SocialPushSession session, {
    required bool retryConflict,
  }) async {
    final revision = await _nextMutationRevision();
    try {
      await _api.unregister(
        bearer: session.credential.token,
        installationId: _record!.installationId,
        mutationRevision: revision,
      );
    } on SocialPushApiException catch (error) {
      if (retryConflict &&
          error.statusCode == 409 &&
          await _adoptLatestRevision(error.latestMutationRevision)) {
        return _unregisterAttempt(session, retryConflict: false);
      }
      rethrow;
    }
  }

  Future<void> _rotateProviderTokenNow({bool updateStatus = true}) async {
    _clearRegisteredSignature();
    if (platform != null) {
      final tokenDeleted = await _disableInitializedProviderState();
      if (tokenDeleted) _providerTokenCleanupPending = false;
    }
    if (updateStatus) {
      _deliveryActive = false;
      _registrationStatus = _statusWithoutRegistration();
      _emitState();
    }
  }

  Future<void> _captureTapNow(
    Map<String, Object?> message,
    int captureGeneration,
  ) async {
    if (_resetting ||
        _tapCaptureBlocked ||
        captureGeneration != _tapCaptureGeneration) {
      return;
    }
    final payload = parseSocialPushPayload(
      message,
      environment: environment,
    );
    if (payload == null) return;
    await _ensureRecordPersisted();
    if (_tapCaptureBlocked || captureGeneration != _tapCaptureGeneration) {
      return;
    }
    final candidate = _record!.copyWith(
      pending: PendingSocialNotification(
        notificationId: payload.notificationId,
        recipientBinding: payload.recipientBinding,
        receivedAt: _now().toUtc(),
      ),
    );
    await _persistence.save(candidate);
    if (_tapCaptureBlocked || captureGeneration != _tapCaptureGeneration) {
      // A synchronous account boundary invalidated this capture while the
      // write was in flight. Its queued fence rewrites the cleared record.
      _recordPersisted = false;
      return;
    }
    _record = candidate;
    _recordPersisted = true;
    _tapEvents.add(null);
  }

  int _fenceTapCaptureAtAccountBoundary() {
    final generation = ++_tapCaptureGeneration;
    _tapCaptureBlocked = true;
    final record = _record;
    if (record?.pending != null) {
      _record = record!.copyWith(clearPending: true);
      _recordPersisted = false;
    }
    return generation;
  }

  int _beginRotatingAccountBoundary() {
    final generation = _fenceTapCaptureAtAccountBoundary();
    _providerTokenCleanupPending = true;
    _providerRotationBoundaryGeneration = generation;
    return generation;
  }

  void _scheduleAccountBoundary(
    int boundaryGeneration, {
    SocialPushSession? sessionToUnregister,
  }) {
    _runDetached(
      initialize().then(
        (_) => _enqueue(
          () => _completeAccountBoundaryNow(
            boundaryGeneration,
            sessionToUnregister: sessionToUnregister,
          ),
        ),
      ),
      'provider token rotation',
    );
  }

  Future<void> _completeAccountBoundaryNow(
    int boundaryGeneration, {
    SocialPushSession? sessionToUnregister,
  }) async {
    var pendingClearPersisted = false;
    try {
      await _ensureRecordPersisted();
      pendingClearPersisted = true;
    } catch (error) {
      debugPrint(
        '[SocialPush] Pending notification fence could not be persisted '
        '(${error.runtimeType})',
      );
    }
    await _rotateProviderTokenNow();
    if (sessionToUnregister != null && (_record?.mutationRevision ?? 0) > 0) {
      await _unregisterNow(sessionToUnregister);
    }
    if (_providerRotationBoundaryGeneration != boundaryGeneration) return;
    _providerRotationBoundaryGeneration = null;
    if (pendingClearPersisted &&
        boundaryGeneration == _tapCaptureGeneration &&
        _session != null &&
        !_resetting) {
      _tapCaptureBlocked = false;
    }
    if (_session != null && !_resetting) {
      await _reconcileNow();
    }
  }

  Future<void> _handleForegroundNow(Map<String, Object?> message) async {
    final payload = parseSocialPushPayload(message, environment: environment);
    final session = _session;
    final record = _record;
    if (payload == null || session == null || record == null) return;
    final expectedBinding = socialPushRecipientBinding(
      installationId: record.installationId,
      userId: session.userId,
      environment: environment,
    );
    if (payload.recipientBinding == expectedBinding) {
      _foregroundInvalidationRevision += 1;
      _foregroundEvents.add(null);
    }
  }

  Future<int> _nextMutationRevision() async {
    final current = _record!.mutationRevision;
    if (current >= SocialPushRecord.maxMutationRevision) {
      throw StateError('Social push mutation revision exhausted');
    }
    final next = current + 1;
    await _replaceRecord(_record!.copyWith(mutationRevision: next));
    return next;
  }

  Future<bool> _adoptLatestRevision(int? latest) async {
    if (latest == null ||
        latest < _record!.mutationRevision ||
        latest >= SocialPushRecord.maxMutationRevision) {
      return false;
    }
    await _replaceRecord(_record!.copyWith(mutationRevision: latest));
    return true;
  }

  Future<void> _ensureRecordPersisted() async {
    if (_recordPersisted) return;
    await _persistence.save(_record!);
    _recordPersisted = true;
  }

  Future<void> _replaceRecord(SocialPushRecord record) async {
    await _persistence.save(record);
    _record = record;
    _recordPersisted = true;
    _emitState();
  }

  SocialPushRegistrationStatus _statusWithoutRegistration() {
    final record = _record;
    if (record == null || !record.optedIn) {
      return SocialPushRegistrationStatus.disabled;
    }
    if (_permission == SocialPushPermission.denied) {
      return SocialPushRegistrationStatus.permissionDenied;
    }
    return SocialPushRegistrationStatus.unregistered;
  }

  void _clearRegisteredSignature() {
    _registeredSession = null;
    _registeredProviderToken = null;
    _registeredPermission = null;
  }

  void _emitState() {
    final state = currentState;
    final previous = _lastEmittedState;
    if (previous != null &&
        previous.enabled == state.enabled &&
        previous.permission == state.permission &&
        previous.registrationStatus == state.registrationStatus &&
        previous.deliveryActive == state.deliveryActive) {
      return;
    }
    _lastEmittedState = state;
    if (!_stateEvents.isClosed) _stateEvents.add(state);
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    final previous = _queueTail;
    _queueTail = () async {
      await previous;
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    }();
    return result.future;
  }

  void _runDetached(Future<void> future, String operation) {
    unawaited(future.catchError((Object error, StackTrace _) {
      debugPrint(
        '[SocialPush] $operation failed (${error.runtimeType})',
      );
    }));
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _stateEvents.close();
    await _tapEvents.close();
    await _foregroundEvents.close();
  }
}
