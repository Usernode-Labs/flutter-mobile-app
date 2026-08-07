part of '../dapp_webview_screen.dart';

/// The `Usernode` JS-channel dispatch table: protocol version,
/// capability list, and the message router that fans out to the
/// domain mixins.
mixin _BridgeDispatch
    on
        _DappWebViewScreenStateBase,
        _BridgeTxRecords,
        _BridgeAuthNode,
        _BridgeWallet,
        _BridgeShortcuts,
        _BridgeSettings,
        _BridgeSocialPush {
  /// Bridge protocol version. Bump only on breaking changes; additive
  /// methods just append to [_bridgeCapabilities] so SV chrome can
  /// feature-detect (`capabilities.includes(...)`) instead of duck-typing.
  static const int _bridgeVersion = 4;
  static const List<String> _bridgeCapabilities = [
    'getNodeAddress',
    'sendTransaction',
    'signMessage',
    'txObserved',
    'getHomeScreenShortcutSupport',
    'addHomeScreenShortcut',
    'getHomeScreenShortcuts',
    'removeHomeScreenShortcut',
    'reorderHomeScreenShortcuts',
    'openExternal',
    'getBridgeInfo',
    // Privileged envelopes bootstrap a per-main-navigation capability through
    // the private `getPrivilegedBridgeCapability` method.
    'privilegedBridgeCapability',
    'getNodeStatus',
    'nodeStatusEvents',
    'getWalletState',
    'getTransactionRecords',
    'openNativeScreen',
    'getProfileInfo',
    'getSettingsState',
    'setNodeSleepEnabled',
    'setDebugMode',
    'setFacematchStrict',
    'resetZkChallenge',
    'requestPermissions',
    'openBatterySettings',
    // Granular permission surface (Option B): node-coupled alarm/battery
    // prompt after startNode, notification prompt at SV product moments.
    'requestNotificationPermission',
    'requestAlarmPermissions',
    'openNotificationSettings',
    // Flag-only: `startNode` responses carry an `alarmPermissions` block.
    'startNodeAlarmPermissions',
    'logout',
    // Bridge v4 (thin-shell migration): platform login + node lifecycle.
    'beginSessionHandoff',
    'enterAnonymousSession',
    'completeLogin',
    'startNode',
    'stopNode',
    'getAuthStatus',
    'authStatusEvents',
    'sessionBoundAuthStatus',
    // Social remote notifications (additive bridge-v4 capabilities).
    'getSocialPushState',
    'setSocialPushEnabled',
    'claimPendingSocialNotification',
    'ackPendingSocialNotification',
  ];

  /// Routes every `Usernode` JS-channel message to its domain handler.
  /// Body moved verbatim from the former inline `onMessageReceived`
  /// closure in initState.
  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final method = payload['method'] as String?;
      final id = payload['id'] as String?;
      debugPrint('[Usernode JS-channel] method=$method id=$id');
      if (method == null) return;

      // `titleChanged` is a fire-and-forget signal from the page that
      // `document.title` has been updated outside of a real navigation
      // (e.g. an SPA route change without a pushState, or a deferred
      // title set after data finishes loading). webview_flutter's
      // onUrlChange-based `_refreshPageTitle` only catches title
      // changes that happen at navigation moments; without this
      // channel, the AppBar's `_pageTitle` lags one navigation
      // behind the page's actual title. Unlike the other methods
      // here, there's no pending JS promise to resolve, so we don't
      // require `id`.
      if (method == 'titleChanged') {
        // Use `.toString()` rather than `as String?` so we don't
        // throw on unexpected payload shapes (the cast surfaced as
        // a silent setState-skip when the value happened to come
        // back as a non-String).
        final raw = payload['value']?.toString().trim();
        final newTitle = (raw == null || raw.isEmpty) ? null : raw;
        debugPrint(
          '[Usernode JS-channel] titleChanged value="$newTitle" '
          'current="$_pageTitle" mounted=$mounted',
        );
        if (!mounted) return;
        // Pin to the channel as the source of truth for this page
        // load. Without this, the very next pushState-driven
        // onUrlChange will run `_refreshPageTitle`, see WKWebView's
        // stale getTitle() value (the *previous* screen's title)
        // and clobber the value we're about to set with setState
        // below — visible as `titleChanged value="dApps"` followed
        // by `build _pageTitle="whiteboard"` in the logs.
        _titleFromChannel = true;
        if (newTitle == _pageTitle) return;
        setState(() => _pageTitle = newTitle);
        return;
      }

      if (id == null) return;

      if (method == 'getPrivilegedBridgeCapability') {
        final capability = _privilegedBridgePolicy.bootstrapCapability();
        await _resolveJsPromise(
          id: id,
          value: capability,
          error: capability == null
              ? 'Privileged bridge is unavailable for this main frame'
              : null,
        );
        return;
      }

      if (_privilegedBridgePolicy.requiresCapability(method) &&
          !_privilegedBridgePolicy.authorizes(
            payload['privilegedCapability'],
          )) {
        await _resolveJsPromise(
          id: id,
          value: null,
          error: '$method requires a trusted top-frame capability',
        );
        return;
      }

      // This check lives in the central channel dispatch so a child frame
      // calling the injected Usernode channel directly cannot bypass the
      // page-side relay's handoff gate.
      if (_sessionHandoffGate.blocks(method)) {
        await _resolveJsPromise(
          id: id,
          value: null,
          error: '$method is unavailable during session handoff',
        );
        return;
      }

      if (method == 'beginSessionHandoff') {
        _sessionHandoffGate.begin();
        await _resolveJsPromise(
          id: id,
          value: const {'blocked': true},
          error: null,
        );
        return;
      }

      if (method == 'enterAnonymousSession') {
        _admitSessionHandoff();
        await _resolveJsPromise(
          id: id,
          value: const {'admitted': true},
          error: null,
        );
        return;
      }

      // Any handler that throws before resolving would otherwise leave
      // the page's JS promise pending forever (the outer catch below
      // only logs, and by then the id may be unknown). Reject here so a
      // bridge caller always settles instead of hanging.
      try {
        if (method == 'getNodeAddress') {
          final address = _bridgeWalletIdentity()?.address;
          if (address == null || address.isEmpty) {
            await _resolveJsPromise(
              id: id,
              value: null,
              error: 'No active account/address available',
            );
          } else {
            await _resolveJsPromise(id: id, value: address, error: null);
          }
        }

        if (method == 'sendTransaction') {
          await _handleSendTransaction(id, payload);
        }

        if (method == 'signMessage') {
          await _handleSignMessage(id, payload);
        }

        if (method == 'txObserved') {
          await _handleTxObserved(payload);
        }

        if (method == 'getHomeScreenShortcutSupport') {
          await _handleGetHomeScreenShortcutSupport(id);
        }

        if (method == 'addHomeScreenShortcut') {
          await _handleAddHomeScreenShortcut(id, payload);
        }

        if (method == 'getHomeScreenShortcuts') {
          await _handleGetHomeScreenShortcuts(id);
        }

        if (method == 'removeHomeScreenShortcut') {
          await _handleRemoveHomeScreenShortcut(id, payload);
        }

        if (method == 'reorderHomeScreenShortcuts') {
          await _handleReorderHomeScreenShortcuts(id, payload);
        }

        if (method == 'openExternal') {
          await _handleOpenExternal(id, payload);
        }

        if (method == 'getBridgeInfo') {
          await _resolveJsPromise(
            id: id,
            value: {
              'version': _bridgeVersion,
              'capabilities': _bridgeCapabilities,
            },
            error: null,
          );
        }

        if (method == 'getNodeStatus') {
          await _resolveJsPromise(
            id: id,
            value: _nodeStatusSnapshot(),
            error: null,
          );
        }

        if (method == 'getWalletState') {
          await _handleGetWalletState(id);
        }

        if (method == 'getTransactionRecords') {
          await _handleGetTransactionRecords(id);
        }

        if (method == 'openNativeScreen') {
          await _handleOpenNativeScreen(id, payload);
        }

        if (method == 'getProfileInfo') {
          await _handleGetProfileInfo(id);
        }

        if (method == 'getSettingsState') {
          await _handleGetSettingsState(id);
        }

        if (method == 'setNodeSleepEnabled') {
          await _handleSetNodeSleepEnabled(id, payload);
        }

        if (method == 'setDebugMode') {
          await _handleSetDebugMode(id, payload);
        }

        if (method == 'setFacematchStrict') {
          await _handleSetFacematchStrict(id, payload);
        }

        if (method == 'resetZkChallenge') {
          await _handleResetZkChallenge(id);
        }

        if (method == 'requestPermissions') {
          await _handleRequestPermissions(id);
        }

        if (method == 'openBatterySettings') {
          await _handleOpenBatterySettings(id);
        }

        if (method == 'requestNotificationPermission') {
          await _handleRequestNotificationPermission(id);
        }

        if (method == 'requestAlarmPermissions') {
          await _handleRequestAlarmPermissions(id);
        }

        if (method == 'openNotificationSettings') {
          await _handleOpenNotificationSettings(id);
        }

        if (method == 'logout') {
          await _handleLogout(id);
        }

        if (method == 'completeLogin') {
          await _handleCompleteLogin(id, payload);
        }

        if (method == 'startNode') {
          await _handleStartNode(id, payload);
        }

        if (method == 'stopNode') {
          await _handleStopNode(id);
        }

        if (method == 'getAuthStatus') {
          await _handleGetAuthStatus(id);
        }

        if (method == 'getSocialPushState') {
          await _handleGetSocialPushState(id);
        }

        if (method == 'setSocialPushEnabled') {
          await _handleSetSocialPushEnabled(id, payload);
        }

        if (method == 'claimPendingSocialNotification') {
          await _handleClaimPendingSocialNotification(id);
        }

        if (method == 'ackPendingSocialNotification') {
          await _handleAckPendingSocialNotification(id, payload);
        }
      } catch (e, st) {
        debugPrint('[Usernode JS-channel] handler error method=$method id=$id: '
            '$e\n$st');
        await _resolveJsPromise(id: id, value: null, error: 'Internal error');
      }
    } catch (e, st) {
      // Surface dispatch failures so we don't end up with a silently
      // hung pending promise on the JS side. The id may not have been
      // parsed yet, in which case there is no resolver to call.
      debugPrint('[Usernode JS-channel] dispatch error: $e\n$st');
    }
  }
}
