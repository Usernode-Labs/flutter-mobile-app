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

  void _dispatchSocialPushEvent(String eventName) {
    if (!widget.chromeless) return;
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

  @override
  void _recordReadySocialPushReplay(
    PrivilegedBridgeLease lease,
    int foregroundRevision,
  ) {
    if (foregroundRevision <= 0) return;
    if (_lastSocialPushForegroundRealmMarker == lease.marker &&
        foregroundRevision <= _lastSocialPushForegroundRevision) {
      return;
    }
    _lastSocialPushForegroundRealmMarker = lease.marker;
    _lastSocialPushForegroundRevision = foregroundRevision;
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
    if (revision <= deliveredRevision ||
        !widget.chromeless ||
        readyLease == null ||
        _sessionHandoffGate.isAuthenticatedBlocked) {
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
          readyLease.marker == _readyMainFrameLease?.marker &&
          !_sessionHandoffGate.isAuthenticatedBlocked) {
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
    if (!await _revalidatePrivilegedBridgeLease(id, 'setSocialPushEnabled')) {
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
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'claimPendingSocialNotification',
    )) {
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
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'ackPendingSocialNotification',
    )) {
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
