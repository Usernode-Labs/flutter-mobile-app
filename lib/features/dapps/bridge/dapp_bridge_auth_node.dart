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
    return _authStatusSnapshotFor(ref.read(identityProvider));
  }

  Map<String, dynamic> _authStatusSnapshotFor(Identity identity) {
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

  /// `completeLogin` (bridge v4): the platform hands over the mobile bearer
  /// token it minted from its own web session (POST
  /// /api/v4/mobile/auth/from-session) plus that response's `user` object.
  /// Initial login stays in this runtime and resolves the settled auth
  /// snapshot. Replacing an authenticated participant acknowledges the
  /// accepted runtime cutover before this WebView is removed. Neither path
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

    final current = ref.read(identityProvider);
    final controller = ref.read(identityProvider.notifier);
    final replacingParticipant = current.isAuthenticated &&
        current.participantId != session.participant.id;

    if (replacingParticipant) {
      // Calling the controller admits the transition and synchronously closes
      // the old identity gate when its queue is idle. This WebView is terminal
      // from here: consume the transition locally without later touching ref
      // or JavaScript, then acknowledge that a restart has been accepted.
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
    final applied = await controller.completeLogin(
      session,
      expectedIdentity: current,
    );
    if (!mounted) return;
    if (!applied) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    var responseIdentity = ref.read(identityProvider);
    if (responseIdentity.epoch != expectedEpoch ||
        responseIdentity.participantId != session.participant.id) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    if (sameParticipant) {
      final response = _authStatusSnapshotFor(responseIdentity);
      await _resolveJsPromise(
        id: id,
        value: response,
        error: null,
      );
      return;
    }
    // The identity driver also reacts to the reconciling publish; the
    // reconciler coalesces per epoch so this direct call just gives the
    // page a Future that settles when provisioning is done.
    try {
      await ref.read(nodeAccountReconcilerProvider).reconcile();
    } catch (e) {
      if (!mounted) return;
      responseIdentity = ref.read(identityProvider);
      if (responseIdentity.epoch != expectedEpoch ||
          responseIdentity.participantId != session.participant.id) {
        await _rejectStaleIdentityScope(id, 'completeLogin');
        return;
      }
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Wallet provisioning failed: $e',
      );
      return;
    }
    if (!mounted) return;
    responseIdentity = ref.read(identityProvider);
    if (responseIdentity.epoch != expectedEpoch ||
        responseIdentity.participantId != session.participant.id ||
        responseIdentity.phase != IdentityPhase.ready) {
      await _rejectStaleIdentityScope(id, 'completeLogin');
      return;
    }
    final response = _authStatusSnapshotFor(responseIdentity);
    await _resolveJsPromise(id: id, value: response, error: null);
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

  /// `logout`: web-side confirm/cache fence, then native commit. The terminal
  /// acknowledgement is delivered after the controller admits the terminal
  /// transition; the caller must not require follow-up JS work.
  Future<void> _handleLogout(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'logout')) return;
    if (!mounted) return;
    final identity = ref.read(identityProvider);
    final controller = ref.read(identityProvider.notifier);
    // Start the terminal transition before resolving. Its completion is
    // deliberately detached: every late path is log-only because the runtime
    // owns this WebView once logout has been admitted.
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
    if (ref.read(identityProvider).phase != IdentityPhase.ready) return;
    // Same Android block-production wiring as the bridge startNode handler,
    // via the shared coordinator.
    await NodeLifecycleCoordinator.instance.startNode(
      reason: 'standalone_dapp_entry',
    );
  }
}
