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
  /// without polling. Fired on chrome pill-state transitions and once per
  /// page load (see initState / onPageFinished).
  void _dispatchNodeStatusEvent() {
    final detail = jsonEncode(_nodeStatusSnapshot());
    _controller
        .runJavaScript('window.dispatchEvent(new CustomEvent('
            '"usernode:node-status", { detail: $detail }));')
        .catchError((_) {});
  }

  /// One JSON shape shared by the `getAuthStatus` reply and the pushed
  /// `usernode:auth-status` CustomEvent (bridge v4). `phase` is the
  /// identity phase name (unknown | transitioning | unauthenticated |
  /// guest | reconciling | ready); `address` is non-null only for a ready
  /// identity that owns a wallet — exactly what SV chrome needs to know
  /// when it may request a node start.
  Map<String, dynamic> _authStatusSnapshot() {
    final identity = ref.read(identityProvider);
    return {
      'phase': identity.phase.name,
      'address':
          identity.phase == IdentityPhase.ready ? identity.address : null,
    };
  }

  /// Pushes the current identity phase into the page as a
  /// `usernode:auth-status` CustomEvent (same convention as
  /// `usernode:node-status`) so SV chrome can render login/provisioning
  /// progress and knows when to request a node start.
  void _dispatchAuthStatusEvent() {
    final detail = jsonEncode(_authStatusSnapshot());
    _controller
        .runJavaScript('window.dispatchEvent(new CustomEvent('
            '"usernode:auth-status", { detail: $detail }));')
        .catchError((_) {});
  }

  /// `completeLogin` (bridge v4): the platform hands over the mobile
  /// bearer token it minted from its own web session
  /// (POST /api/v4/mobile/auth/from-session) plus that response's `user`
  /// object. Runs the same identity transition a native sign-in used to:
  /// SessionController.completeLogin stages the credential and suspends
  /// the node, then the reconciler provisions/imports the custodial
  /// wallet. Resolves the settled auth snapshot — WITHOUT starting the
  /// node (node lifecycle is platform-controlled; SV calls startNode).
  Future<void> _handleCompleteLogin(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'completeLogin')) return;
    final args = payload['args'];
    final token =
        args is Map<String, dynamic> ? args['token']?.toString() : null;
    final user = args is Map<String, dynamic> && args['user'] is Map
        ? (args['user'] as Map).cast<String, dynamic>()
        : null;
    if (token == null || token.isEmpty || user == null || user['id'] is! num) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'args.token (string) and args.user ({id, ...}) are required',
      );
      return;
    }
    final session = AuthSession(
      token: token,
      participant: Participant(
        id: (user['id'] as num).toInt(),
        // Web-only platform accounts may have no email; the identity
        // machinery keys off the participant id, so an empty string is
        // safe here.
        email: user['email']?.toString() ?? '',
        emailConfirmed: user['email_confirmed'] == true,
        displayName: user['display_name']?.toString(),
      ),
    );

    // Idempotent boot handoff: SV re-runs this on every shell boot. When
    // the same user is already settled, don't tear the identity down just
    // to rebuild it.
    final current = ref.read(identityProvider);
    if (current.phase == IdentityPhase.ready &&
        current.participantId == session.participant.id) {
      await _resolveJsPromise(
          id: id, value: _authStatusSnapshot(), error: null);
      return;
    }

    await ref.read(identityProvider.notifier).completeLogin(session);
    // The identity driver also reacts to the reconciling publish; the
    // reconciler coalesces per epoch so this direct call just gives the
    // page a Future that settles when provisioning is done.
    try {
      await ref.read(nodeAccountReconcilerProvider).reconcile();
    } catch (e) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Wallet provisioning failed: $e',
      );
      return;
    }
    await _resolveJsPromise(id: id, value: _authStatusSnapshot(), error: null);
  }

  /// `startNode` (bridge v4): platform-requested node start, bound to the
  /// current identity's wallet. Refused unless the identity is settled
  /// (ready) and the requested address (when provided) matches it — the
  /// page can never start the node under someone else's account.
  Future<void> _handleStartNode(String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'startNode')) return;
    final args = payload['args'];
    final address =
        args is Map<String, dynamic> ? args['address']?.toString() : null;
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
    if (address != null && address.isNotEmpty && address != identity.address) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'address does not belong to the current identity',
      );
      return;
    }
    // The coordinator owns the Android block-production wiring (watchdog
    // recovery, audit, foreground service) atomically with the start.
    final started = await NodeLifecycleCoordinator.instance.startNode(
      reason: 'platform_start',
    );
    await _resolveJsPromise(
      id: id,
      value: {'started': started, 'nodeStatus': _nodeStatusSnapshot()},
      error: started ? null : 'Node failed to start',
    );
  }

  /// `stopNode` (bridge v4): platform-requested node stop. Idempotent —
  /// stopping an already-stopped node resolves normally.
  Future<void> _handleStopNode(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'stopNode')) return;
    await NodeLifecycleCoordinator.instance.stopNode(reason: 'platform_stop');
    await _resolveJsPromise(id: id, value: {'stopped': true}, error: null);
  }

  /// `getAuthStatus` (bridge v4): poll-style twin of the
  /// `usernode:auth-status` event, for boot-time orchestration.
  Future<void> _handleGetAuthStatus(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'getAuthStatus')) return;
    await _resolveJsPromise(id: id, value: _authStatusSnapshot(), error: null);
  }

  /// `logout`: web-side confirm, native commit. The router's auth guard
  /// takes over from here (post-logout flow stays native chrome, same
  /// category as onboarding).
  Future<void> _handleLogout(String id) async {
    final identity = ref.read(identityProvider);
    if (!await _requireTrustedChromeOrigin(id, 'logout')) return;
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'logout');
      return;
    }
    final loggedOut = await ref
        .read(identityProvider.notifier)
        .logout(expectedIdentity: identity);
    if (!loggedOut) {
      await _rejectStaleIdentityScope(id, 'logout');
      return;
    }
    await _resolveJsPromise(id: id, value: true, error: null);
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
    if (ref.read(identityProvider).phase != IdentityPhase.ready) return;
    // Same Android block-production wiring as the bridge startNode handler,
    // via the shared coordinator.
    await NodeLifecycleCoordinator.instance.startNode(
      reason: 'standalone_dapp_entry',
    );
  }
}
