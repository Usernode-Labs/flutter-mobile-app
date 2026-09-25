part of '../dapp_webview_screen.dart';

/// Minimal Social remote-notification bridge. Authentication and top-frame
/// authority remain owned by bridge v4; only nonsecret state and an opaque
/// notification id cross this boundary.
mixin _BridgeSocialPush on _DappWebViewScreenStateBase {
  StreamSubscription<SocialPushState>? _socialPushStateSubscription;
  StreamSubscription<void>? _socialPushTapSubscription;
  StreamSubscription<void>? _socialPushForegroundSubscription;
  String? _lastSocialPushForegroundRealmMarker;
  int _lastSocialPushForegroundRevision = 0;
  bool _socialPushForegroundDispatchInFlight = false;
  bool _socialPushForegroundReplayRequested = false;

  void _listenForSocialPushEvents() {
    final service = SocialPushService.instance;
    _socialPushStateSubscription = service.stateEvents.listen(
      (_) => _dispatchSocialPushEvent(
        'usernode:social-push-native-state-changed',
      ),
    );
    _socialPushTapSubscription = service.tapEvents.listen(
      (_) => _dispatchSocialPushEvent('usernode:social-push-pending'),
    );
    _socialPushForegroundSubscription = service.foregroundEvents.listen(
      (_) => _dispatchPendingSocialPushForegroundEvent(),
    );
  }

  // Every DappWebViewScreen instance hosts the SV shell now (the legacy
  // standalone browser is gone), so social-push events dispatch
  // unconditionally; the trusted-realm lease still gates delivery.
  void _dispatchSocialPushEvent(String eventName) {
    unawaited(_dispatchSocialPushEventIfTrusted(eventName));
  }

  Future<void> _dispatchSocialPushEventIfTrusted(String eventName) async {
    await _runInReadyMainFrame(
      'window.dispatchEvent(new CustomEvent(${jsonEncode(eventName)}));',
    );
  }

  @override
  void _dispatchPendingSocialPushEvents() {
    // Read the authoritative native state again for every newly-ready or
    // BFCache-restored realm. Its JavaScript cache may have gone stale while a
    // different document was active.
    _dispatchSocialPushEvent('usernode:social-push-native-state-changed');
    if (SocialPushService.instance.hasPendingTap) {
      _dispatchSocialPushEvent('usernode:social-push-pending');
    }
    _dispatchPendingSocialPushForegroundEvent();
  }

  void _dispatchPendingSocialPushForegroundEvent() {
    if (_socialPushForegroundDispatchInFlight) {
      _socialPushForegroundReplayRequested = true;
      return;
    }
    final service = SocialPushService.instance;
    final revision = service.foregroundInvalidationRevision;
    final readyLease = _readyMainFrameLease;
    final deliveredRevision = readyLease != null &&
            readyLease.marker == _lastSocialPushForegroundRealmMarker
        ? _lastSocialPushForegroundRevision
        : 0;
    if (revision <= deliveredRevision || readyLease == null) {
      return;
    }
    _socialPushForegroundDispatchInFlight = true;
    _socialPushForegroundReplayRequested = false;
    unawaited(
      _dispatchSocialPushForegroundEvent(
        readyLease,
        revision,
      ),
    );
  }

  Future<void> _dispatchSocialPushForegroundEvent(
    PrivilegedBridgeLease readyLease,
    int revision,
  ) async {
    try {
      final delivered = await _privilegedBridgePolicy.runInLease(
        readyLease,
        'window.dispatchEvent(new CustomEvent('
        '"usernode:social-push-foreground"));',
      );
      if (delivered &&
          mounted &&
          readyLease.marker == _readyMainFrameLease?.marker) {
        _lastSocialPushForegroundRealmMarker = readyLease.marker;
        _lastSocialPushForegroundRevision = revision;
      }
    } catch (_) {
      // A later page admission or foreground message retries the invalidation.
    } finally {
      _socialPushForegroundDispatchInFlight = false;
    }

    final replayRequested = _socialPushForegroundReplayRequested;
    _socialPushForegroundReplayRequested = false;
    if (mounted &&
        (replayRequested ||
            SocialPushService.instance.foregroundInvalidationRevision >
                revision)) {
      _dispatchPendingSocialPushForegroundEvent();
    }
  }

  void _disposeSocialPushEvents() {
    unawaited(_socialPushStateSubscription?.cancel());
    unawaited(_socialPushTapSubscription?.cancel());
    unawaited(_socialPushForegroundSubscription?.cancel());
  }

  Future<void> _handleGetSocialPushState(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'getSocialPushState',
        body: (_, __) async =>
            (await SocialPushService.instance.refreshState()).toBridgeJson(),
      );

  Future<void> _handleSetSocialPushEnabled(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final args = payload['args'];
    final enabled = args is Map<String, dynamic> ? args['enabled'] : null;
    if (enabled is! bool) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'args.enabled (boolean) is required',
      );
      return;
    }
    await _resolveClaimedSessionOperation(
      id: id,
      payload: payload,
      method: 'setSocialPushEnabled',
      body: (_, __) async =>
          (await SocialPushService.instance.setEnabled(enabled)).toBridgeJson(),
    );
  }

  Future<void> _handleClaimPendingSocialNotification(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'claimPendingSocialNotification',
        body: (identity, _) async {
          final userId = identity.participantId!;
          final notificationId = await SocialPushService.instance
              .claimPendingNotification(userId: userId);
          return notificationId == null
              ? null
              : {'notificationId': notificationId};
        },
      );

  Future<void> _handleAckPendingSocialNotification(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final args = payload['args'];
    final rawNotificationId =
        args is Map<String, dynamic> ? args['notificationId'] : null;
    final notificationId =
        rawNotificationId is num ? rawNotificationId.toInt() : null;
    if (notificationId == null ||
        notificationId <= 0 ||
        notificationId > 2147483647 ||
        rawNotificationId != notificationId) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'args.notificationId must be a positive integer',
      );
      return;
    }
    await _resolveClaimedSessionOperation(
      id: id,
      payload: payload,
      method: 'ackPendingSocialNotification',
      body: (identity, _) =>
          SocialPushService.instance.acknowledgePendingNotification(
        userId: identity.participantId!,
        notificationId: notificationId,
      ),
    );
  }
}
