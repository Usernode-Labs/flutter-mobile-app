part of '../dapp_webview_screen.dart';

/// Minimal Social remote-notification bridge. Authentication and top-frame
/// authority remain owned by bridge v4; only nonsecret state and an opaque
/// notification id cross this boundary.
mixin _BridgeSocialPush on _DappWebViewScreenStateBase {
  StreamSubscription<SocialPushState>? _socialPushStateSubscription;
  StreamSubscription<void>? _socialPushTapSubscription;
  StreamSubscription<void>? _socialPushForegroundSubscription;
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

  void _dispatchSocialPushEvent(String eventName) {
    if (!widget.chromeless || !_privilegedBridgePolicy.hasActiveCapability) {
      return;
    }
    _controller
        .runJavaScript(
          'window.dispatchEvent(new CustomEvent("$eventName"));',
        )
        .catchError((_) {});
  }

  @override
  void _dispatchPendingSocialPushEvents() {
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
    if (revision <= _lastSocialPushForegroundRevision ||
        !widget.chromeless ||
        _sessionHandoffGate.isAuthenticatedBlocked) {
      return;
    }
    final capability = _privilegedBridgePolicy.bootstrapCapability();
    if (capability == null) return;

    _socialPushForegroundDispatchInFlight = true;
    _socialPushForegroundReplayRequested = false;
    unawaited(_dispatchSocialPushForegroundEvent(capability, revision));
  }

  Future<void> _dispatchSocialPushForegroundEvent(
    String capability,
    int revision,
  ) async {
    try {
      await _controller.runJavaScript(
        'window.dispatchEvent(new CustomEvent('
        '"usernode:social-push-foreground"));',
      );
      if (mounted &&
          !_sessionHandoffGate.isAuthenticatedBlocked &&
          _privilegedBridgePolicy.authorizes(capability)) {
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

  Future<void> _handleGetSocialPushState(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'getSocialPushState')) return;
    final identity = ref.read(identityProvider);
    if (!_sessionHandoffGate.authenticates(identity)) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'An authenticated session is required',
      );
      return;
    }
    final state = await SocialPushService.instance.refreshState();
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'getSocialPushState');
      return;
    }
    await _resolveJsPromise(
      id: id,
      value: state.toBridgeJson(),
      error: null,
    );
  }

  Future<void> _handleSetSocialPushEnabled(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (!await _requireTrustedChromeOrigin(id, 'setSocialPushEnabled')) return;
    final identity = ref.read(identityProvider);
    if (!_sessionHandoffGate.authenticates(identity)) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'An authenticated session is required',
      );
      return;
    }
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
    final state = await SocialPushService.instance.setEnabled(enabled);
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'setSocialPushEnabled');
      return;
    }
    await _resolveJsPromise(
      id: id,
      value: state.toBridgeJson(),
      error: null,
    );
  }

  Future<void> _handleClaimPendingSocialNotification(String id) async {
    if (!await _requireTrustedChromeOrigin(
      id,
      'claimPendingSocialNotification',
    )) {
      return;
    }
    final identity = ref.read(identityProvider);
    final userId = identity.participantId;
    if (!_sessionHandoffGate.authenticates(identity) || userId == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'An authenticated session is required',
      );
      return;
    }
    final notificationId = await SocialPushService.instance
        .claimPendingNotification(userId: userId);
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'claimPendingSocialNotification');
      return;
    }
    await _resolveJsPromise(
      id: id,
      value: notificationId == null ? null : {'notificationId': notificationId},
      error: null,
    );
  }

  Future<void> _handleAckPendingSocialNotification(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (!await _requireTrustedChromeOrigin(
      id,
      'ackPendingSocialNotification',
    )) {
      return;
    }
    final identity = ref.read(identityProvider);
    final userId = identity.participantId;
    if (!_sessionHandoffGate.authenticates(identity) || userId == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'An authenticated session is required',
      );
      return;
    }
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
    final acknowledged =
        await SocialPushService.instance.acknowledgePendingNotification(
      userId: userId,
      notificationId: notificationId,
    );
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'ackPendingSocialNotification');
      return;
    }
    await _resolveJsPromise(
      id: id,
      value: acknowledged,
      error: null,
    );
  }
}
