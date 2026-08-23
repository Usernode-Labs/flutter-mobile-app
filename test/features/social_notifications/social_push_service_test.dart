import 'dart:async';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_binding.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_api.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_messaging.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_payload.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/session_authority_test_helpers.dart';

const _environment = 'production';
const _projectId = 'usernode-test';
const _installationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  test('push binding needs authentication, not wallet readiness', () {
    const reconciling = Identity(
      epoch: 3,
      phase: IdentityPhase.reconciling,
      participantId: 42,
    );

    expect(canAttachSocialPushSession(reconciling), isTrue);
    expect(
      canAttachSocialPushSession(
        reconciling.copyWith(clearParticipantId: true),
      ),
      isFalse,
    );
    expect(
      canAttachSocialPushSession(
        reconciling.copyWith(phase: IdentityPhase.unauthenticated),
      ),
      isFalse,
    );
  });

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
    expect(
      rig.api.unregisterCalls.single.reason,
      SocialPushUnregisterReason.identityBoundary,
    );
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
    expect(
      rig.api.unregisterCalls.single.reason,
      SocialPushUnregisterReason.notificationsDisabled,
    );
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
    expect(
      rig.api.unregisterCalls.single.reason,
      SocialPushUnregisterReason.accountChanged,
    );

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

  test('iOS retries when APNs becomes ready without a refresh callback',
      () async {
    final rig = _rig(optedIn: true, platform: 'ios');
    addTearDown(rig.dispose);
    rig.messaging.apnsToken = null;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();

    expect(rig.messaging.getApnsTokenCalls, 1);
    expect(rig.messaging.getTokenCalls, 0);
    expect(rig.api.registerCalls, isEmpty);
    expect(rig.activeRetryTimers, hasLength(1));
    final retry = rig.activeRetryTimers.single;
    expect(retry.delay, const Duration(seconds: 1));

    rig.messaging.apnsToken = 'late-apns-token';
    retry.fire();
    await rig.settle();

    expect(rig.api.registerCalls, hasLength(1));
    expect(rig.api.registerCalls.single.registrationToken, 'fcm-token');
    expect(rig.activeRetryTimers, isEmpty);
    expect(
      rig.service.currentState.registrationStatus,
      SocialPushRegistrationStatus.registered,
    );
  });

  test('Android retries when the FCM token becomes available', () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    rig.messaging.initialToken = null;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();

    expect(rig.messaging.getTokenCalls, 1);
    expect(rig.api.registerCalls, isEmpty);
    final retry = rig.activeRetryTimers.single;

    rig.messaging.initialToken = 'late-fcm-token';
    retry.fire();
    await rig.settle();

    expect(rig.api.registerCalls, hasLength(1));
    expect(
      rig.api.registerCalls.single.registrationToken,
      'late-fcm-token',
    );
    expect(rig.activeRetryTimers, isEmpty);
  });

  test('cold-start permission read failures recover through bounded retry',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    // Initialization and the first attached reconcile both fail before a
    // trustworthy authorization state is available.
    rig.messaging.getPermissionFailuresRemaining = 2;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();

    expect(rig.messaging.getPermissionCalls, 2);
    expect(rig.api.registerCalls, isEmpty);
    final retry = rig.activeRetryTimers.single;

    retry.fire();
    await rig.settle();

    expect(rig.messaging.getPermissionCalls, 3);
    expect(rig.api.registerCalls, hasLength(1));
    expect(rig.activeRetryTimers, isEmpty);
  });

  test('a failed permission request rechecks authorization in the background',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.messaging.requestPermissionFailuresRemaining = 1;
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.settle();

    final state = await rig.service.setEnabled(true);

    expect(state.registrationStatus, SocialPushRegistrationStatus.error);
    final retry = rig.activeRetryTimers.single;
    retry.fire();
    await rig.settle();

    expect(rig.api.registerCalls, hasLength(1));
    expect(
      rig.service.currentState.registrationStatus,
      SocialPushRegistrationStatus.registered,
    );
  });

  test('an explicit reconcile starts a fresh budget after retry exhaustion',
      () async {
    final rig = _rig(
      optedIn: true,
      registrationRetryDelays: const [Duration(seconds: 1)],
    );
    addTearDown(rig.dispose);
    rig.messaging.initialToken = null;
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.settle();

    rig.activeRetryTimers.single.fire();
    await rig.settle();
    expect(rig.activeRetryTimers, isEmpty);
    expect(rig.messaging.getTokenCalls, 2);

    await rig.service.reconcile();
    expect(rig.activeRetryTimers, hasLength(1));
    expect(
      rig.activeRetryTimers.single.delay,
      const Duration(seconds: 1),
    );

    rig.messaging.initialToken = 'token-after-resume';
    rig.activeRetryTimers.single.fire();
    await rig.settle();
    expect(
        rig.api.registerCalls.single.registrationToken, 'token-after-resume');
  });

  test('transient registration upload failures use bounded backoff', () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    rig.api.onRegister = (_) async {
      if (rig.api.registerCalls.length < 3) {
        throw const SocialPushApiException(statusCode: 503);
      }
      return const SocialPushRegistrationReply(
        registered: true,
        deliveryActive: true,
      );
    };
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    expect(rig.api.registerCalls, hasLength(1));
    final firstRetry = rig.activeRetryTimers.single;
    expect(firstRetry.delay, const Duration(seconds: 1));

    firstRetry.fire();
    await rig.settle();
    expect(rig.api.registerCalls, hasLength(2));
    final secondRetry = rig.activeRetryTimers.single;
    expect(secondRetry.delay, const Duration(seconds: 2));

    secondRetry.fire();
    await rig.settle();
    expect(rig.api.registerCalls, hasLength(3));
    expect(rig.activeRetryTimers, isEmpty);
    expect(
      rig.service.currentState.registrationStatus,
      SocialPushRegistrationStatus.registered,
    );
  });

  test('permanent registration failures do not schedule retries', () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    rig.api.onRegister =
        (_) async => throw const SocialPushApiException(statusCode: 400);
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();

    expect(rig.api.registerCalls, hasLength(1));
    expect(rig.activeRetryTimers, isEmpty);
    expect(
      rig.service.currentState.registrationStatus,
      SocialPushRegistrationStatus.error,
    );
  });

  test('successful provider shutdown is idempotent while ineligible', () async {
    final optedOut = _rig();
    final denied = _rig(optedIn: true);
    final alreadyUnbound = _rig();
    addTearDown(optedOut.dispose);
    addTearDown(denied.dispose);
    addTearDown(alreadyUnbound.dispose);
    denied.messaging.permission = SocialPushPermission.denied;

    await optedOut.service.initialize();
    optedOut.service.attachSession(optedOut.owner, _session());
    await optedOut.settle();
    await optedOut.service.reconcile();
    await optedOut.service.reconcile();

    await denied.service.initialize();
    denied.service.attachSession(denied.owner, _session());
    await denied.settle();
    await denied.service.reconcile();
    await denied.service.reconcile();

    await alreadyUnbound.service.initialize();
    alreadyUnbound.service.detachSession(
      alreadyUnbound.owner,
      rotateProviderToken: true,
      ifAlreadyUnbound: true,
    );
    await alreadyUnbound.settle();
    alreadyUnbound.service.detachSession(
      alreadyUnbound.owner,
      rotateProviderToken: true,
      ifAlreadyUnbound: true,
    );
    await alreadyUnbound.settle();

    expect(optedOut.messaging.deleteTokenCalls, 1);
    expect(denied.messaging.deleteTokenCalls, 1);
    expect(alreadyUnbound.messaging.deleteTokenCalls, 1);
  });

  test('a failed provider deletion remains retryable but then becomes stable',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.messaging.deleteTokenFailuresRemaining = 1;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    expect(rig.messaging.deleteTokenCalls, 1);

    await rig.service.reconcile();
    await rig.service.reconcile();

    expect(rig.messaging.deleteTokenCalls, 2);
    expect(rig.messaging.deleteTokenFailuresRemaining, 0);
    expect(
        rig.messaging.autoInitCalls.where((enabled) => !enabled), hasLength(1));
  });

  test('auto-init recovery performs one final ordered token deletion',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.messaging.setAutoInitFailuresRemaining = 1;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    expect(rig.messaging.deleteTokenCalls, 1);

    await rig.service.reconcile();
    await rig.service.reconcile();

    expect(
        rig.messaging.autoInitCalls.where((enabled) => !enabled), hasLength(2));
    expect(rig.messaging.setAutoInitFailuresRemaining, 0);
    expect(rig.messaging.deleteTokenCalls, 2);
  });

  test('persistent auto-init failure does not repeatedly delete the token',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.messaging.setAutoInitFailuresRemaining = 10;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    await rig.service.reconcile();
    await rig.service.reconcile();
    await rig.service.reconcile();

    expect(
        rig.messaging.autoInitCalls.where((enabled) => !enabled), hasLength(4));
    expect(rig.messaging.deleteTokenCalls, 1);
  });

  test('combined shutdown failures retry deletion then order the final delete',
      () async {
    final rig = _rig();
    addTearDown(rig.dispose);
    rig.messaging.setAutoInitFailuresRemaining = 3;
    rig.messaging.deleteTokenFailuresRemaining = 1;
    await rig.service.initialize();

    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    expect(rig.messaging.deleteTokenCalls, 1);

    // Both operations retry; this early deletion succeeds but cannot be final
    // while auto-init is still unconfirmed.
    await rig.service.reconcile();
    expect(rig.messaging.deleteTokenCalls, 2);

    // A successful early deletion is not repeated on every failed auto-init.
    await rig.service.reconcile();
    expect(rig.messaging.deleteTokenCalls, 2);

    // Once auto-init is confirmed disabled, delete once more in that order.
    await rig.service.reconcile();
    await rig.service.reconcile();

    expect(
        rig.messaging.autoInitCalls.where((enabled) => !enabled), hasLength(4));
    expect(rig.messaging.deleteTokenFailuresRemaining, 0);
    expect(rig.messaging.deleteTokenCalls, 3);
  });

  test('a disabled account fences an already-fired registration retry',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    rig.messaging.initialToken = null;
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    final staleRetry = rig.activeRetryTimers.single;

    await rig.service.setEnabled(false);
    final tokenReadsAfterDisable = rig.messaging.getTokenCalls;
    staleRetry.fireStale();
    await rig.settle();

    expect(staleRetry.isActive, isFalse);
    expect(rig.messaging.getTokenCalls, tokenReadsAfterDisable);
    expect(rig.api.registerCalls, isEmpty);
    expect(rig.activeRetryTimers, isEmpty);
  });

  test('an account switch fences the old retry and registers only the new user',
      () async {
    final rig = _rig(optedIn: true);
    addTearDown(rig.dispose);
    rig.messaging.initialToken = null;
    await rig.service.initialize();
    rig.service.attachSession(rig.owner, _session());
    await rig.settle();
    final staleRetry = rig.activeRetryTimers.single;

    rig.service.attachSession(
      Object(),
      _session(userId: 84, epoch: 2, bearer: 'bearer-84'),
    );
    await rig.settle();
    staleRetry.fireStale();
    await rig.settle();

    expect(rig.api.registerCalls, isEmpty);
    expect(rig.activeRetryTimers, hasLength(1));
    rig.messaging.initialToken = 'new-user-token';
    rig.activeRetryTimers.single.fire();
    await rig.settle();

    expect(rig.api.registerCalls, hasLength(1));
    expect(rig.api.registerCalls.single.bearer, 'bearer-84');
    expect(rig.api.registerCalls.single.registrationToken, 'new-user-token');
  });

  test('terminal reset and dispose cancel registration recovery', () async {
    final resetRig = _rig(optedIn: true);
    addTearDown(resetRig.dispose);
    resetRig.messaging.initialToken = null;
    await resetRig.service.initialize();
    resetRig.service.attachSession(resetRig.owner, _session());
    await resetRig.settle();
    final resetRetry = resetRig.activeRetryTimers.single;

    resetRig.service.closeForTerminalReset();
    await resetRig.settle();
    final resetTokenReads = resetRig.messaging.getTokenCalls;
    resetRetry.fireStale();
    await resetRig.settle();
    expect(resetRig.messaging.getTokenCalls, resetTokenReads);
    expect(resetRig.api.registerCalls, isEmpty);

    final disposedRig = _rig(optedIn: true);
    disposedRig.messaging.initialToken = null;
    await disposedRig.service.initialize();
    disposedRig.service.attachSession(disposedRig.owner, _session());
    await disposedRig.settle();
    final disposedRetry = disposedRig.activeRetryTimers.single;
    await disposedRig.dispose();
    final disposedTokenReads = disposedRig.messaging.getTokenCalls;

    disposedRetry.fireStale();
    await disposedRig.settle();
    expect(disposedRig.messaging.getTokenCalls, disposedTokenReads);
    expect(disposedRig.api.registerCalls, isEmpty);
  });

  for (final platform in ['android', 'ios']) {
    test('$platform re-registers after an account-boundary token deletion',
        () async {
      final rig = _rig(optedIn: true, platform: platform);
      addTearDown(rig.dispose);
      rig.messaging.initialToken = 'token-a';
      rig.messaging.deleteTokenClearsToken = true;
      await rig.service.initialize();
      rig.service.attachSession(rig.owner, _session());
      await rig.settle();
      expect(rig.api.registerCalls.single.registrationToken, 'token-a');

      rig.service.detachSession(rig.owner, rotateProviderToken: true);
      await rig.settle();
      expect(rig.messaging.initialToken, isNull);
      expect(
        rig.api.unregisterCalls.single.reason,
        SocialPushUnregisterReason.identityBoundary,
      );

      rig.service.attachSession(
        rig.owner,
        _session(epoch: 2, bearer: 'renewed-bearer-42'),
      );
      await rig.settle();
      expect(rig.activeRetryTimers, hasLength(1));

      rig.messaging.initialToken = 'token-b';
      rig.messaging.tokenRefresh.add('token-b');
      await rig.settle();

      expect(
        rig.api.registerCalls.map((call) => call.registrationToken),
        ['token-a', 'token-b'],
      );
      expect(rig.api.registerCalls.last.bearer, 'renewed-bearer-42');
      expect(rig.activeRetryTimers, isEmpty);
    });
  }

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
    expect(
      rig.api.unregisterCalls.single.reason,
      SocialPushUnregisterReason.permissionDenied,
    );

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
      credential: testCredentialLease(
        epoch: epoch,
        token: bearer,
        sessionId: 'session-$userId',
        credentialRef: 'credential-$userId',
        credentialGeneration: epoch,
      ),
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
  String platform = 'android',
  List<Duration> registrationRetryDelays = const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ],
}) {
  final trace = <String>[];
  final retryTimers = <_ManualTimer>[];
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
    platform: platform,
    now: () => DateTime.utc(2026, 8, 3, 12),
    registrationRetryDelays: registrationRetryDelays,
    createRetryTimer: (delay, callback) {
      final timer = _ManualTimer(delay, callback);
      retryTimers.add(timer);
      return timer;
    },
  );
  return _Rig(service, messaging, persistence, api, trace, retryTimers);
}

class _Rig {
  _Rig(
    this.service,
    this.messaging,
    this.persistence,
    this.api,
    this.trace,
    this.retryTimers,
  );

  final SocialPushService service;
  final _FakeMessaging messaging;
  final _MemoryPersistence persistence;
  final _FakeApi api;
  final List<String> trace;
  final List<_ManualTimer> retryTimers;
  final Object owner = Object();

  Iterable<_ManualTimer> get activeRetryTimers =>
      retryTimers.where((timer) => timer.isActive);

  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await service.refreshState();
  }

  Future<void> settle() async {
    for (var index = 0; index < 5; index++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    await service.dispose();
    await messaging.dispose();
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  void fireStale() => _callback();
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
  String? apnsToken = 'apns-token';
  Map<String, Object?>? initialMessage;
  int deleteTokenCalls = 0;
  int deleteTokenFailuresRemaining = 0;
  int getApnsTokenCalls = 0;
  int getPermissionCalls = 0;
  int getPermissionFailuresRemaining = 0;
  int getTokenCalls = 0;
  int getTokenFailuresRemaining = 0;
  int requestPermissionCalls = 0;
  int requestPermissionFailuresRemaining = 0;
  int setAutoInitFailuresRemaining = 0;
  bool deleteTokenClearsToken = false;

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
  Future<SocialPushPermission> getPermission() async {
    getPermissionCalls++;
    if (getPermissionFailuresRemaining > 0) {
      getPermissionFailuresRemaining--;
      throw StateError('simulated getPermission failure');
    }
    return permission;
  }

  @override
  Future<SocialPushPermission> requestPermission() async {
    requestPermissionCalls++;
    if (requestPermissionFailuresRemaining > 0) {
      requestPermissionFailuresRemaining--;
      throw StateError('simulated requestPermission failure');
    }
    return permission;
  }

  @override
  Future<String?> getApnsToken() async {
    getApnsTokenCalls++;
    return apnsToken;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    if (getTokenFailuresRemaining > 0) {
      getTokenFailuresRemaining--;
      throw StateError('simulated getToken failure');
    }
    return initialToken;
  }

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    trace.add('TOKEN_DELETE');
    if (deleteTokenFailuresRemaining > 0) {
      deleteTokenFailuresRemaining--;
      throw StateError('simulated deleteToken failure');
    }
    if (deleteTokenClearsToken) initialToken = null;
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    autoInitCalls.add(enabled);
    if (setAutoInitFailuresRemaining > 0) {
      setAutoInitFailuresRemaining--;
      throw StateError('simulated setAutoInitEnabled failure');
    }
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
  SocialPushUnregisterReason reason,
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
    required AuthCredentialLease credential,
    required String installationId,
  }) async {
    final bearer = credential.token;
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
    required AuthCredentialLease credential,
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  }) async {
    final bearer = credential.token;
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
    required AuthCredentialLease credential,
    required String installationId,
    required int mutationRevision,
    required SocialPushUnregisterReason reason,
  }) async {
    final bearer = credential.token;
    operations.add('DELETE');
    trace.add('DELETE:$bearer');
    unregisterCalls.add((
      bearer: bearer,
      installationId: installationId,
      mutationRevision: mutationRevision,
      reason: reason,
    ));
    registered = false;
    deliveryActive = false;
  }
}
