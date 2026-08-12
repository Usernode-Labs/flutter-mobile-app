part of '../dapp_webview_screen.dart';

/// Bridge v4 auth + node lifecycle: identity/node status snapshots and
/// push events, `completeLogin`, `startNode`/`stopNode` (via
/// [NodeLifecycleCoordinator]), `getAuthStatus`, `logout`, and the
/// standalone-dapp-entry node ensure.
mixin _BridgeAuthNode on _DappWebViewScreenStateBase {
  /// One JSON shape shared by the `getNodeStatus` reply and the pushed
  /// `usernode:node-status` CustomEvent, so SV renders both identically.
  /// `status` is the chrome-level pill state (hysteresis applied):
  /// synced | syncing | connecting | offline.
  @override
  Map<String, dynamic> _nodeStatusSnapshot() {
    final chrome = ref.read(topStatusChromeNodeStatusProvider);
    final node = ref.read(nodeStatusProvider).valueOrNull;
    return {
      'status': chrome.name,
      'localBestHeight': node?.localBestHeight,
      'networkBestHeight': node?.networkBestHeight,
      'connectedPeers': node?.connectedPeers,
      'totalPeers': node?.totalPeers,
    };
  }

  /// Pushes the current node status into the page as a
  /// `usernode:node-status` CustomEvent, so SV's header pill can update
  /// without polling. Fired on chrome pill-state transitions and replayed
  /// after the page explicitly confirms that its native-event listeners exist.
  void _dispatchNodeStatusEvent() {
    final detail = jsonEncode(_nodeStatusSnapshot());
    unawaited(
      _runInReadyMainFrame(
        'window.dispatchEvent(new CustomEvent('
        '"usernode:node-status", { detail: $detail }));',
      ),
    );
  }

  /// One JSON shape shared by the `getAuthStatus` reply and the pushed
  /// `usernode:auth-status` CustomEvent (bridge v4). `phase` is the
  /// identity phase name (unknown | transitioning | unauthenticated |
  /// guest | reconciling | ready); `participantId` and `epoch` bind every
  /// ready address to the exact native session SV must echo into `startNode`.
  @override
  Map<String, dynamic> _authStatusSnapshot() {
    return _authStatusSnapshotFor(ref.read(identityProvider));
  }

  Map<String, dynamic> _authStatusSnapshotFor(Identity identity) {
    return sessionBoundAuthStatus(
      identity,
      reconciliationStatus: ref.read(accountReconciliationStatusProvider).name,
    );
  }

  /// Pushes the current identity phase into the page as a
  /// `usernode:auth-status` CustomEvent (same convention as
  /// `usernode:node-status`) so SV chrome can render login/provisioning
  /// progress and knows when to request a node start.
  void _dispatchAuthStatusEvent() {
    final detail = jsonEncode(_authStatusSnapshot());
    unawaited(
      _runInReadyMainFrame(
        'window.dispatchEvent(new CustomEvent('
        '"usernode:auth-status", { detail: $detail }));',
      ),
    );
  }

  /// `completeLogin` (bridge v4): the platform hands over the mobile bearer
  /// token it minted from its own web session (POST
  /// /api/v4/mobile/auth/from-session). The legacy `user` payload is checked
  /// for mismatch only; native derives the participant from authenticated
  /// `/api/v4/mobile/me` so token and participant cannot diverge.
  /// Initial login and a same-participant bearer renewal stay in this runtime
  /// and resolve as soon as the bearer and participant are installed. Account
  /// reconciliation continues behind that authenticated boundary; only wallet
  /// and node methods wait for [IdentityPhase.ready]. Replacing an
  /// authenticated participant enters the terminal reset boundary. No path
  /// starts the node — lifecycle remains platform-controlled.
  Future<void> _handleCompleteLogin(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'completeLogin')) return;
    final args = payload['args'];
    final token =
        args is Map<String, dynamic> ? args['token']?.toString() : null;
    final user = args is Map<String, dynamic> && args['user'] is Map
        ? (args['user'] as Map).cast<String, dynamic>()
        : null;
    if (token == null || token.isEmpty) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'args.token (string) is required',
      );
      return;
    }
    final legacyUserId = user?['id'];
    if (user != null && legacyUserId is! num) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'args.user.id must be numeric when args.user is supplied',
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(id, 'completeLogin')) return;
    final current = ref.read(identityProvider);
    AuthSession session;
    try {
      session = await ref.read(authRepositoryProvider).resolveBearerSession(
            token,
            legacyParticipantId: (legacyUserId as num?)?.toInt(),
          );
    } catch (error) {
      debugPrint('[Usernode JS-channel] bearer validation failed: $error');
      if (!mounted) return;
      if (!_identityScopeIsCurrent(current)) {
        await _rejectStaleIdentityScope(id, 'completeLogin');
        return;
      }
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Session validation failed',
      );
      return;
    }
    if (!mounted) return;
    if (!_identityScopeIsCurrent(current)) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    final controller = ref.read(identityProvider.notifier);
    final replacingParticipant = current.isAuthenticated &&
        current.participantId != session.participant.id;

    if (replacingParticipant) {
      await controller.transitionsSettled;
      if (!mounted) return;
      if (!_identityScopeIsCurrent(current)) {
        await _rejectStaleIdentityScope(id, 'completeLogin');
        return;
      }
      if (!await _revalidatePrivilegedBridgeLease(id, 'completeLogin')) return;
      // A different authenticated participant is unsupported in-process.
      // Start the terminal transition, then answer the initiating page without
      // touching Riverpod again.
      _sessionHandoffGate.closeForTerminalReset();
      final transition = controller.completeLogin(
        session,
        expectedIdentity: current,
      );
      unawaited(transition.then<void>(
        (applied) {
          if (!applied) {
            debugPrint(
              '[Usernode JS-channel] terminal completeLogin was rejected',
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            '[Usernode JS-channel] terminal completeLogin failed: '
            '$error\n$stackTrace',
          );
        },
      ));
      await _resolveJsPromise(
        id: id,
        value: const {'restarting': true},
        error: null,
      );
      return;
    }

    final sameParticipant = current.isAuthenticated &&
        current.participantId == session.participant.id;
    final expectedEpoch = sameParticipant ? current.epoch : current.epoch + 1;
    if (!await _revalidatePrivilegedBridgeLease(id, 'completeLogin')) return;
    final applied = await controller.completeLogin(
      session,
      expectedIdentity: current,
    );
    if (!mounted) return;
    if (!applied) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    final responseIdentity = ref.read(identityProvider);
    if (responseIdentity.epoch != expectedEpoch ||
        responseIdentity.participantId != session.participant.id) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    if (!_admitAuthenticatedSession(responseIdentity)) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    if (responseIdentity.phase == IdentityPhase.ready) {
      _admitWalletSession(responseIdentity);
    }
    final response = _authStatusSnapshotFor(responseIdentity);
    await _resolveJsPromise(id: id, value: response, error: null);
  }

  /// `startNode` (bridge v4): platform-requested node start, bound to the
  /// current identity's wallet. Refused unless the identity is settled
  /// (ready), the echoed participant/epoch/address match, and an authoritative
  /// account refresh succeeds without changing that scope.
  Future<void> _handleStartNode(String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'startNode')) return;
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'startNode requires args.address, args.participantId, and '
            'args.epoch',
      );
      return;
    }
    final address = args['address']?.toString();
    final participantIdRaw = args['participantId'];
    final epochRaw = args['epoch'];
    final participantId =
        participantIdRaw is num ? participantIdRaw.toInt() : null;
    final epoch = epochRaw is num ? epochRaw.toInt() : null;
    final identity = ref.read(identityProvider);
    if (identity.phase != IdentityPhase.ready) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Identity is ${identity.phase.name}; node start requires a '
            'settled (ready) identity',
      );
      return;
    }
    if (participantId == null ||
        epoch == null ||
        address == null ||
        address.isEmpty ||
        !sessionScopeMatchesReadyIdentity(
          identity,
          participantId: participantId,
          epoch: epoch,
          address: address,
        )) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'startNode identity scope is stale',
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(id, 'startNode')) return;
    final fresh =
        await ref.read(identityDriverProvider).ensureFreshBeforeNodeStart();
    if (!mounted) return;
    final refreshedIdentity = ref.read(identityProvider);
    if (!fresh) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Could not refresh the current account state',
      );
      return;
    }
    if (!identity.sameScopeAs(refreshedIdentity) ||
        !sessionScopeMatchesReadyIdentity(
          refreshedIdentity,
          participantId: participantId,
          epoch: epoch,
          address: address,
        )) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'startNode identity changed during refresh',
      );
      return;
    }
    // The coordinator owns the Android block-production wiring (watchdog
    // recovery, audit, foreground service) atomically with the start.
    if (!await _revalidatePrivilegedBridgeLease(id, 'startNode')) return;
    final started = await NodeLifecycleCoordinator.instance.startNode(
      reason: 'platform_start',
    );
    // Alarm/battery state rides along so SV can show its "node needs alarm &
    // battery" sheet at the one moment it matters (runs on every cold start,
    // so revoked permissions get re-flagged too). Not-applicable off Android.
    final alarmPermissions =
        await PlatformAlarmService.instance.alarmPermissionsSnapshot();
    await _resolveJsPromise(
      id: id,
      value: {
        'started': started,
        'nodeStatus': _nodeStatusSnapshot(),
        'alarmPermissions': alarmPermissions,
      },
      error: started ? null : 'Node failed to start',
    );
  }

  /// `stopNode` (bridge v4): platform-requested node stop. Idempotent —
  /// stopping an already-stopped node resolves normally.
  Future<void> _handleStopNode(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'stopNode')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'stopNode')) return;
    await NodeLifecycleCoordinator.instance.stopNode(reason: 'platform_stop');
    await _resolveJsPromise(id: id, value: {'stopped': true}, error: null);
  }

  /// `getAuthStatus` (bridge v4): poll-style twin of the
  /// `usernode:auth-status` event, for boot-time orchestration.
  Future<void> _handleGetAuthStatus(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'getAuthStatus')) return;
    await _resolveJsPromise(id: id, value: _authStatusSnapshot(), error: null);
  }

  /// `logout`: web-side confirm/cache fence, then native commit. The terminal
  /// acknowledgement is delivered after the controller admits the terminal
  /// transition; the caller must not require follow-up JS work.
  Future<void> _handleLogout(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'logout')) return;
    if (!mounted) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'logout')) return;
    final controller = ref.read(identityProvider.notifier);
    await controller.transitionsSettled;
    if (!mounted) return;
    final identity = ref.read(identityProvider);
    // Start the terminal transition before resolving. Its completion is
    // deliberately detached: every late path is log-only because the runtime
    // owns this WebView once logout has been admitted.
    if (!await _revalidatePrivilegedBridgeLease(id, 'logout')) return;
    _sessionHandoffGate.closeForTerminalReset();
    final transition = controller.logout(expectedIdentity: identity);
    unawaited(transition.then<void>(
      (loggedOut) {
        if (!loggedOut) {
          debugPrint('[Usernode JS-channel] terminal logout was rejected');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[Usernode JS-channel] terminal logout failed: '
          '$error\n$stackTrace',
        );
      },
    ));
    await _resolveJsPromise(
      id: id,
      value: true,
      error: null,
    );
  }

  /// Standalone dapp surfaces (widget/shortcut deep links to
  /// `/dapps/pinned/<id>`, `/dapps/<slug>` routes) can be entered on a cold
  /// start without the SV shell ever loading — and the shell is the only
  /// thing that requests a node start over bridge v4. Sends from every dapp
  /// surface go through the local node's wallet RPC, so without this a
  /// shell-bypassing entry leaves the node stopped and every send failing
  /// with "Node RPC unavailable". Mirrors the bridge `startNode` handler:
  /// identity-gated (startNode itself refuses unsettled identities), and
  /// block production stays gated by bp_released inside NodeService, so
  /// this cannot start producing for an unreleased user.
  ///
  /// No-op for the SV shell instance ([DappWebViewScreen.chromeless]) —
  /// the platform owns node lifecycle there — and while app sleep is
  /// active (the sleep service owns the node then).
  Future<void> _ensureNodeForStandaloneDappEntry() async {
    if (widget.chromeless) return;
    if (!mounted) return;
    if (RustBackendService.instance.isRunning) return;
    if (AppSleepStateStore.isSleeping) return;
    final identity = ref.read(identityProvider);
    if (identity.phase != IdentityPhase.ready) return;
    if (!await ref.read(identityDriverProvider).ensureFreshBeforeNodeStart()) {
      return;
    }
    if (!mounted || !identity.sameScopeAs(ref.read(identityProvider))) return;
    // Same Android block-production wiring as the bridge startNode handler,
    // via the shared coordinator.
    await NodeLifecycleCoordinator.instance.startNode(
      reason: 'standalone_dapp_entry',
    );
  }
}
