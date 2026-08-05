import 'dart:async';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_api.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_messaging.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_payload.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _environment = 'production';
const _projectId = 'usernode-test';
const _installationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  test('ordinary startup preserves the token while identity restores',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);

    await rig.service.initialize();

    expect(rig.messaging.deleteTokenCalls, 0);

    rig.service.attachSession(rig.owner, _session());
    await rig.drain();

    expect(rig.messaging.deleteTokenCalls, 0);
    expect(rig.api.registerCalls.single.registrationToken, 'fcm-token');
    expect(rig.service.currentState.registrationStatus,
        SocialPushRegistrationStatus.registered);
  });

  test('logout unregisters the user and retries native token cleanup',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    final deletesBeforeLogout = rig.messaging.deleteTokenCalls;
    rig.messaging.deleteTokenFailuresRemaining = 2;

    rig.service.detachSession(rig.owner, rotateProviderToken: true);
    await rig.drain();

    expect(rig.api.unregisterCalls, hasLength(1));
    expect(rig.api.unregisterCalls.single.bearer, 'bearer-42');
    expect(rig.messaging.deleteTokenFailuresRemaining, 0);
    expect(
      rig.messaging.deleteTokenCalls,
      greaterThanOrEqualTo(deletesBeforeLogout + 2),
    );

    rig.service.attachSession(
      rig.owner,
      _session(epoch: 2, bearer: 'renewed-bearer-42'),
    );
    await rig.drain();
    final deletesAfterRelogin = rig.messaging.deleteTokenCalls;
    rig.service.detachSession(rig.owner, rotateProviderToken: false);
    await rig.service.refreshState();

    expect(rig.messaging.deleteTokenCalls, deletesAfterRelogin);
  });

  test('same-user credential renewal does not delete the native token',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    final deletesBeforeRenewal = rig.messaging.deleteTokenCalls;

    rig.service.detachSession(rig.owner, rotateProviderToken: false);
    await rig.service.refreshState();

    expect(rig.messaging.deleteTokenCalls, deletesBeforeRenewal);
    expect(rig.api.unregisterCalls, isEmpty);
  });

  test('enable registers and disable rotates then unregisters', () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();

    final enabled = await rig.service.setEnabled(true);

    expect(enabled.enabled, isTrue);
    expect(enabled.registrationStatus, SocialPushRegistrationStatus.registered);
    expect(enabled.deliveryActive, isTrue);
    expect(rig.api.registerCalls, hasLength(1));
    expect(rig.api.registerCalls.single.bearer, 'bearer-42');
    expect(rig.api.registerCalls.single.registrationToken, 'fcm-token');
    expect(rig.api.registerCalls.single.mutationRevision, 1);
    expect(rig.api.operations.take(2), ['GET', 'PUT']);
    final deletesBeforeDisable = rig.messaging.deleteTokenCalls;

    final disabled = await rig.service.setEnabled(false);

    expect(disabled.enabled, isFalse);
    expect(disabled.registrationStatus, SocialPushRegistrationStatus.disabled);
    expect(disabled.deliveryActive, isFalse);
    expect(rig.messaging.autoInitCalls.last, isFalse);
    expect(rig.messaging.deleteTokenCalls, deletesBeforeDisable + 1);
    expect(rig.api.unregisterCalls, hasLength(1));
    expect(rig.api.unregisterCalls.single.bearer, 'bearer-42');
    expect(rig.api.unregisterCalls.single.mutationRevision, 2);
  });

  test('opted-out recovery shuts Firebase down before backend cleanup',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.persistence.record = rig.persistence.record.copyWith(
      mutationRevision: 1,
    );
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());

    await rig.drain();

    expect(rig.messaging.autoInitCalls, contains(false));
    expect(rig.messaging.deleteTokenCalls, greaterThan(0));
    expect(rig.api.unregisterCalls, hasLength(1));
    expect(
      rig.trace.indexOf('TOKEN_DELETE'),
      lessThan(rig.trace.indexOf('DELETE:bearer-42')),
    );
  });

  test('a revision conflict adopts the server revision and retries once',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.api.onRegister = (call) async {
      if (rig.api.registerCalls.length == 1) {
        throw const SocialPushApiException(
          statusCode: 409,
          code: 'stale_mutation_revision',
          latestMutationRevision: 7,
        );
      }
      return const SocialPushRegistrationReply(
        registered: true,
        deliveryActive: true,
      );
    };
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();

    final state = await rig.service.setEnabled(true);

    expect(
      rig.api.registerCalls.map((call) => call.mutationRevision),
      [1, 8],
    );
    expect(rig.persistence.record.mutationRevision, 8);
    expect(state.registrationStatus, SocialPushRegistrationStatus.registered);
  });

  test('a pending tap is claimed and removed only by the matching ack',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    final tap = rig.service.tapEvents.first;

    rig.messaging.opened.add(_payload(
      notificationId: 91,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    ));
    await tap;

    expect(rig.service.hasPendingTap, isTrue);
    expect(
      await rig.service.claimPendingNotification(userId: 42),
      91,
    );
    expect(
      await rig.service.acknowledgePendingNotification(
        userId: 42,
        notificationId: 92,
      ),
      isFalse,
    );
    expect(rig.service.hasPendingTap, isTrue);
    expect(
      await rig.service.acknowledgePendingNotification(
        userId: 42,
        notificationId: 91,
      ),
      isTrue,
    );
    expect(rig.service.hasPendingTap, isFalse);
  });

  test('a delayed old owner cannot detach or publish over the new owner',
      () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<SocialPushRegistrationReply>();
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    rig.api.onRegister = (call) {
      if (rig.api.registerCalls.length == 1) {
        firstStarted.complete();
        return releaseFirst.future;
      }
      return Future.value(const SocialPushRegistrationReply(
        registered: true,
        deliveryActive: false,
      ));
    };
    await rig.service.initialize();
    final oldOwner = Object();
    final newOwner = Object();

    rig.service.attachSession(oldOwner, _session());
    await firstStarted.future;
    rig.service.attachSession(
      newOwner,
      _session(userId: 84, epoch: 2, bearer: 'bearer-84'),
    );
    final deletesBeforeStaleDetach = rig.messaging.deleteTokenCalls;
    rig.service.detachSession(oldOwner, rotateProviderToken: true);
    expect(rig.messaging.deleteTokenCalls, deletesBeforeStaleDetach);
    releaseFirst.complete(const SocialPushRegistrationReply(
      registered: true,
      deliveryActive: true,
    ));
    await rig.drain();

    expect(rig.api.registerCalls.map((call) => call.bearer), [
      'bearer-42',
      'bearer-84',
    ]);
    expect(rig.service.currentState.registrationStatus,
        SocialPushRegistrationStatus.registered);
    expect(rig.service.currentState.deliveryActive, isFalse);
  });

  test('cross-user attach fences taps and rotates before new registration',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    final captured = rig.service.tapEvents.first;
    rig.messaging.opened.add(_payload(
      notificationId: 97,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    ));
    await captured;
    expect(rig.service.hasPendingTap, isTrue);
    rig.trace.clear();
    final deletesBeforeSwitch = rig.messaging.deleteTokenCalls;
    final newOwner = Object();

    rig.service.attachSession(
      newOwner,
      _session(userId: 84, epoch: 2, bearer: 'bearer-84'),
    );

    expect(rig.service.hasPendingTap, isFalse);
    await rig.drain();
    final tokenDelete = rig.trace.indexOf('TOKEN_DELETE');
    final newRegistration = rig.trace.indexOf('PUT:bearer-84');
    expect(rig.messaging.deleteTokenCalls, deletesBeforeSwitch + 1);
    expect(tokenDelete, greaterThanOrEqualTo(0));
    expect(newRegistration, greaterThan(tokenDelete));
    expect(rig.persistence.record.pending, isNull);
    expect(rig.api.registerCalls.last.bearer, 'bearer-84');

    final deletesBeforeLateDetach = rig.messaging.deleteTokenCalls;
    rig.service.detachSession(rig.owner, rotateProviderToken: true);
    await rig.drain();
    expect(rig.messaging.deleteTokenCalls, deletesBeforeLateDetach);
  });

  test('same-user owner and credential renewal does not rotate the token',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    rig.trace.clear();
    final deletesBeforeRenewal = rig.messaging.deleteTokenCalls;

    rig.service.attachSession(
      Object(),
      _session(epoch: 2, bearer: 'renewed-bearer-42'),
    );
    await rig.drain();

    expect(rig.trace, isNot(contains('TOKEN_DELETE')));
    expect(rig.messaging.deleteTokenCalls, deletesBeforeRenewal);
    expect(rig.api.registerCalls.last.bearer, 'renewed-bearer-42');
  });

  test('a mismatched Firebase project fails closed', () async {
    final rig = _rig(actualProjectId: 'another-project');
    addTearDown(rig.dispose);

    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    final state = await rig.service.setEnabled(true);

    expect(state.enabled, isTrue);
    expect(state.registrationStatus, SocialPushRegistrationStatus.error);
    expect(rig.api.registerCalls, isEmpty);
    expect(rig.messaging.requestPermissionCalls, 0);
    expect(rig.messaging.autoInitCalls.last, isFalse);
    expect(rig.messaging.deleteTokenCalls, 1);
  });

  test('missing deployment identity also shuts provider state down', () async {
    final rig = _rig(environment: '');
    addTearDown(rig.dispose);

    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    final state = await rig.service.setEnabled(true);

    expect(state.registrationStatus, SocialPushRegistrationStatus.error);
    expect(rig.api.registerCalls, isEmpty);
    expect(rig.messaging.autoInitCalls, [false]);
    expect(rig.messaging.deleteTokenCalls, 1);
  });

  test('unchanged reconcile avoids another PUT and keeps delivery active',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    await rig.service.setEnabled(true);

    await rig.service.reconcile();
    await rig.service.reconcile();

    expect(rig.api.registerCalls, hasLength(1));
    expect(rig.api.statusCalls, hasLength(3));
    expect(rig.service.currentState.registrationStatus,
        SocialPushRegistrationStatus.registered);
    expect(rig.service.currentState.deliveryActive, isTrue);
  });

  test('refresh reads authoritative delivery state without another PUT',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    await rig.service.setEnabled(true);
    rig.api.deliveryActive = false;

    final refreshed = await rig.service.refreshState();

    expect(
        refreshed.registrationStatus, SocialPushRegistrationStatus.registered);
    expect(refreshed.deliveryActive, isFalse);
    expect(rig.api.registerCalls, hasLength(1));
  });

  test('unchanged status refresh does not re-emit semantic state', () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    await rig.service.setEnabled(true);
    final emitted = <SocialPushState>[];
    final subscription = rig.service.stateEvents.listen(emitted.add);
    addTearDown(subscription.cancel);

    await rig.service.refreshState();
    await rig.service.refreshState();

    expect(emitted, isEmpty);
  });

  test('permission revocation rotates the token and unregisters once',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    await rig.service.setEnabled(true);
    final deletesBeforeRevocation = rig.messaging.deleteTokenCalls;

    rig.messaging.permission = SocialPushPermission.denied;
    await rig.service.reconcile();

    expect(rig.service.currentState.permission, SocialPushPermission.denied);
    expect(rig.service.currentState.registrationStatus,
        SocialPushRegistrationStatus.permissionDenied);
    expect(rig.service.currentState.deliveryActive, isFalse);
    expect(rig.messaging.deleteTokenCalls, deletesBeforeRevocation + 1);
    expect(rig.api.unregisterCalls, hasLength(1));
    expect(rig.api.unregisterCalls.single.bearer, 'bearer-42');
    expect(rig.api.unregisterCalls.single.mutationRevision, 2);

    await rig.service.reconcile();
    expect(rig.api.unregisterCalls, hasLength(1));
  });

  test('foreground events are emitted only for the attached recipient',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    var events = 0;
    final subscription = rig.service.foregroundEvents.listen((_) => events++);
    addTearDown(subscription.cancel);

    rig.messaging.foreground.add(_payload(
      notificationId: 10,
      userId: 84,
      installationId: rig.persistence.record.installationId,
    ));
    await rig.drain();
    expect(events, 0);
    expect(rig.service.foregroundInvalidationRevision, 0);

    rig.messaging.foreground.add(_payload(
      notificationId: 11,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    ));
    await rig.drain();
    expect(events, 1);
    expect(rig.service.foregroundInvalidationRevision, 1);

    await rig.service.refreshState();
    expect(rig.service.foregroundInvalidationRevision, 1);
  });

  test('rotating detach clears pending taps and blocks later captures',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    var tapEvents = 0;
    final subscription = rig.service.tapEvents.listen((_) => tapEvents++);
    addTearDown(subscription.cancel);

    rig.messaging.opened.add(_payload(
      notificationId: 91,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    ));
    await rig.drain();
    expect(rig.service.hasPendingTap, isTrue);
    expect(tapEvents, 1);

    rig.service.detachSession(rig.owner, rotateProviderToken: true);
    expect(rig.service.hasPendingTap, isFalse);
    rig.messaging.opened.add(_payload(
      notificationId: 92,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    ));
    await rig.drain();

    expect(rig.service.hasPendingTap, isFalse);
    expect(rig.persistence.record.pending, isNull);
    expect(tapEvents, 1);

    rig.service.attachSession(
      rig.owner,
      _session(userId: 84, epoch: 2, bearer: 'bearer-84'),
    );
    await rig.drain();
    rig.messaging.opened.add(_payload(
      notificationId: 95,
      userId: 84,
      installationId: rig.persistence.record.installationId,
    ));
    await rig.drain();

    expect(rig.service.hasPendingTap, isTrue);
    expect(tapEvents, 2);
  });

  test('account boundary invalidates a tap whose write is in flight', () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.drain();
    final saveStarted = Completer<void>();
    final releaseSave = Completer<void>();
    rig.persistence.blockNextSave(
      started: saveStarted,
      release: releaseSave,
    );
    var tapEvents = 0;
    final subscription = rig.service.tapEvents.listen((_) => tapEvents++);
    addTearDown(subscription.cancel);

    rig.messaging.opened.add(_payload(
      notificationId: 93,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    ));
    await saveStarted.future;
    rig.service.detachSession(rig.owner, rotateProviderToken: true);
    releaseSave.complete();
    await rig.drain();

    expect(rig.service.hasPendingTap, isFalse);
    expect(rig.persistence.record.pending, isNull);
    expect(tapEvents, 0);
  });

  test('account boundary during initialization rewrites the durable fence',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.persistence.record = rig.persistence.record.copyWith(
      pending: PendingSocialNotification(
        notificationId: 96,
        recipientBinding: socialPushRecipientBinding(
          installationId: rig.persistence.record.installationId,
          userId: 42,
          environment: _environment,
        ),
        receivedAt: DateTime.utc(2026, 8, 3, 11),
      ),
    );
    final saveStarted = Completer<void>();
    final releaseSave = Completer<void>();
    rig.persistence.blockNextSave(
      started: saveStarted,
      release: releaseSave,
    );

    final initialization = rig.service.initialize();
    await saveStarted.future;
    rig.service.detachSession(
      rig.owner,
      rotateProviderToken: true,
      ifAlreadyUnbound: true,
    );
    expect(rig.service.hasPendingTap, isFalse);
    releaseSave.complete();
    await initialization;
    await rig.drain();

    final durableRecord = await rig.persistence.load();
    expect(durableRecord.pending, isNull);
    expect(rig.service.hasPendingTap, isFalse);
  });

  test('cold-start tap survives until restored identity can claim it',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.messaging.initialMessage = _payload(
      notificationId: 94,
      userId: 42,
      installationId: rig.persistence.record.installationId,
    );

    await rig.service.initialize();

    expect(rig.service.hasPendingTap, isTrue);
    expect(await rig.service.claimPendingNotification(userId: 42), 94);
  });
}

SocialPushSession _session({
  int userId = 42,
  int epoch = 1,
  String bearer = 'bearer-42',
}) =>
    SocialPushSession(
      userId: userId,
      credential: AuthCredentialLease(epoch: epoch, token: bearer),
      onUnauthorized: (_) async {},
    );

Map<String, Object?> _payload({
  required int notificationId,
  required int userId,
  required String installationId,
}) =>
    {
      'source': socialPushPayloadSource,
      'schema': socialPushPayloadSchema,
      'environment': _environment,
      'notification_id': '$notificationId',
      'recipient_binding': socialPushRecipientBinding(
        installationId: installationId,
        userId: userId,
        environment: _environment,
      ),
    };

_Rig _rig({
  bool optedIn = false,
  String environment = _environment,
  String actualProjectId = _projectId,
}) {
  final trace = <String>[];
  final messaging = _FakeMessaging(
    projectId: actualProjectId,
    trace: trace,
  );
  final persistence = _MemoryPersistence(SocialPushRecord(
    installationId: _installationId,
    optedIn: optedIn,
    mutationRevision: 0,
  ));
  final api = _FakeApi(trace);
  final service = SocialPushService(
    messaging: messaging,
    persistence: persistence,
    api: api,
    environment: environment,
    expectedFirebaseProjectId: _projectId,
    platform: 'android',
    now: () => DateTime.utc(2026, 8, 3, 12),
  );
  return _Rig(service, messaging, persistence, api, trace);
}

class _Rig {
  _Rig(this.service, this.messaging, this.persistence, this.api, this.trace);

  final SocialPushService service;
  final _FakeMessaging messaging;
  final _MemoryPersistence persistence;
  final _FakeApi api;
  final List<String> trace;
  final Object owner = Object();

  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await service.refreshState();
  }

  Future<void> dispose() async {
    await service.dispose();
    await messaging.dispose();
  }
}

class _FakeMessaging implements SocialPushMessaging {
  _FakeMessaging({required this.projectId, required this.trace});

  final String? projectId;
  final List<String> trace;
  final foreground = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  final opened = StreamController<Map<String, Object?>>.broadcast(sync: true);
  final tokenRefresh = StreamController<String>.broadcast(sync: true);
  final List<bool> autoInitCalls = [];
  SocialPushPermission permission = SocialPushPermission.authorized;
  String? initialToken = 'fcm-token';
  Map<String, Object?>? initialMessage;
  int deleteTokenCalls = 0;
  int deleteTokenFailuresRemaining = 0;
  int requestPermissionCalls = 0;

  @override
  Stream<Map<String, Object?>> get foregroundMessages => foreground.stream;

  @override
  Stream<Map<String, Object?>> get openedMessages => opened.stream;

  @override
  Stream<String> get tokenRefreshes => tokenRefresh.stream;

  @override
  Future<String?> initialize() async => projectId;

  @override
  Future<Map<String, Object?>?> getInitialOpenedMessage() async =>
      initialMessage;

  @override
  Future<SocialPushPermission> getPermission() async => permission;

  @override
  Future<SocialPushPermission> requestPermission() async {
    requestPermissionCalls++;
    return permission;
  }

  @override
  Future<String?> getApnsToken() async => 'apns-token';

  @override
  Future<String?> getToken() async => initialToken;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    trace.add('TOKEN_DELETE');
    if (deleteTokenFailuresRemaining > 0) {
      deleteTokenFailuresRemaining--;
      throw StateError('simulated deleteToken failure');
    }
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    autoInitCalls.add(enabled);
  }

  Future<void> dispose() async {
    await foreground.close();
    await opened.close();
    await tokenRefresh.close();
  }
}

class _MemoryPersistence implements SocialPushPersistence {
  _MemoryPersistence(this.record);

  SocialPushRecord record;
  Completer<void>? _nextSaveStarted;
  Completer<void>? _nextSaveRelease;

  void blockNextSave({
    required Completer<void> started,
    required Completer<void> release,
  }) {
    _nextSaveStarted = started;
    _nextSaveRelease = release;
  }

  @override
  Future<SocialPushRecord> load() async => record;

  @override
  Future<void> save(SocialPushRecord value) async {
    final started = _nextSaveStarted;
    final release = _nextSaveRelease;
    if (started != null && release != null) {
      _nextSaveStarted = null;
      _nextSaveRelease = null;
      started.complete();
      await release.future;
    }
    record = value;
  }

  @override
  Future<void> clear() async {}
}

typedef _RegisterCall = ({
  String bearer,
  String installationId,
  String registrationToken,
  String platform,
  String permissionStatus,
  int mutationRevision,
});
typedef _UnregisterCall = ({
  String bearer,
  String installationId,
  int mutationRevision,
});
typedef _StatusCall = ({
  String bearer,
  String installationId,
});

class _FakeApi implements SocialPushRegistrationApi {
  _FakeApi(this.trace);

  final List<String> trace;
  final operations = <String>[];
  final statusCalls = <_StatusCall>[];
  final registerCalls = <_RegisterCall>[];
  final unregisterCalls = <_UnregisterCall>[];
  Future<SocialPushRegistrationReply> Function(_RegisterCall)? onRegister;
  bool registered = false;
  bool deliveryActive = true;

  @override
  Future<SocialPushRegistrationReply> getStatus({
    required String bearer,
    required String installationId,
  }) async {
    operations.add('GET');
    trace.add('GET:$bearer');
    statusCalls.add((bearer: bearer, installationId: installationId));
    return SocialPushRegistrationReply(
      registered: registered,
      deliveryActive: registered && deliveryActive,
    );
  }

  @override
  Future<SocialPushRegistrationReply> register({
    required String bearer,
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  }) async {
    final call = (
      bearer: bearer,
      installationId: installationId,
      registrationToken: registrationToken,
      platform: platform,
      permissionStatus: permissionStatus,
      mutationRevision: mutationRevision,
    );
    operations.add('PUT');
    trace.add('PUT:$bearer');
    registerCalls.add(call);
    final handler = onRegister;
    final reply = handler == null
        ? const SocialPushRegistrationReply(
            registered: true,
            deliveryActive: true,
          )
        : await handler(call);
    registered = reply.registered;
    deliveryActive = reply.deliveryActive;
    return reply;
  }

  @override
  Future<void> unregister({
    required String bearer,
    required String installationId,
    required int mutationRevision,
  }) async {
    operations.add('DELETE');
    trace.add('DELETE:$bearer');
    unregisterCalls.add((
      bearer: bearer,
      installationId: installationId,
      mutationRevision: mutationRevision,
    ));
    registered = false;
    deliveryActive = false;
  }
}
