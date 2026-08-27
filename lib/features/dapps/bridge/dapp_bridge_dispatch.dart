part of '../dapp_webview_screen.dart';

/// The `Usernode` JS-channel dispatch table: protocol version,
/// capability list, and the message router that fans out to the
/// domain mixins.
mixin _BridgeDispatch
    on
        _DappWebViewScreenStateBase,
        _BridgeAuthNode,
        _BridgeWallet,
        _BridgeShortcuts,
        _BridgeSettings,
        _BridgeSocialPush,
        _BridgeCapture {
  /// Bridge protocol version. Bump only on breaking changes; additive
  /// methods just append to [_bridgeCapabilities] so SV chrome can
  /// feature-detect (`capabilities.includes(...)`) instead of duck-typing.
  // Version 5 removes native product receipt/profile ownership and installs
  // the exact tx-id-returning submitTransaction contract.
  // It does not advertise the later sessionLifecycleProtocol.
  static const int _bridgeVersion = 5;
  static final List<String> _bridgeCapabilities = [
    'getNodeAddress',
    'submitTransaction',
    'signMessage',
    'getHomeScreenShortcutSupport',
    'addHomeScreenShortcut',
    'getHomeScreenShortcuts',
    'removeHomeScreenShortcut',
    'reorderHomeScreenShortcuts',
    'openExternal',
    'getBridgeInfo',
    if (NativeScreenCapture.isSupportedPlatform) 'captureScreenshot',
    // Privileged envelopes bootstrap a realm-scoped capability through the
    // private `getPrivilegedBridgeCapability` method. Native separately checks
    // the executing top-frame origin on every privileged call.
    'privilegedBridgeCapability',
    'getNodeStatus',
    'nodeStatusEvents',
    'getWalletState',
    'manageStaking',
    'openNativeScreen',
    zkIdentityFlowCapability,
    'getSettingsState',
    'setNodeSleepEnabled',
    'setDebugMode',
    'setFacematchStrict',
    'resetZkChallenge',
    'requestPermissions',
    'openBatterySettings',
    // Granular permission surface: producer alarm/battery prompts remain
    // separate from notification prompts at Social product moments.
    'requestNotificationPermission',
    'requestAlarmPermissions',
    'openNotificationSettings',
    'logout',
    'establishNativeSession',
    // The trusted shell emits this after its native-event listeners exist.
    'privilegedBridgeReady',
    // Social remote notifications (additive bridge-v4 capabilities).
    'getSocialPushState',
    'setSocialPushEnabled',
    'claimPendingSocialNotification',
    'ackPendingSocialNotification',
  ];

  /// Platform-aware capability list. Additive, feature-named entries only;
  /// adding a capability does not bump `_bridgeVersion`.
  ///
  /// `homeScreenShortcutDarkIcon` — `addHomeScreenShortcut` accepts an
  /// optional `icon_url_dark` and the WidgetKit tiles select it per system
  /// appearance; omission/null retains an existing dark asset, while an
  /// empty string clears it. `getHomeScreenShortcuts` items carry
  /// `has_icon_dark`.
  /// iOS-only: the flag means "sending a dark icon has a visible effect",
  /// and Android's pinned launcher shortcuts are static bitmaps that can
  /// never flip, so advertising there would make the page ship an asset
  /// that is silently dropped.
  List<String> get _platformBridgeCapabilities => [
        ..._bridgeCapabilities,
        if (HomeShortcutsChannel.isIOS) 'homeScreenShortcutDarkIcon',
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
      // `document.title` has been updated. It used to drive the legacy
      // browser AppBar's title; with that chrome removed nothing native
      // renders the title, but pages (SV's App.setHeaderTitle) still post
      // it — accept and ignore for protocol compatibility.
      if (method == 'titleChanged') return;

      if (id == null) return;

      if (method == 'getPrivilegedBridgeCapability') {
        final lease = await _privilegedBridgePolicy.bootstrapLease();
        if (lease == null) {
          // The failure path contains no secret. It intentionally uses the
          // ordinary resolver because no trusted realm lease was established.
          await _resolveJsPromise(
            id: id,
            value: null,
            error: 'Privileged bridge is unavailable for this main frame',
          );
        } else {
          await _privilegedBridgePolicy.resolve(
            lease: lease,
            id: id,
            value: lease.capability,
            error: null,
          );
        }
        return;
      }

      // Admission is ordered by channel arrival, but handlers run concurrently
      // after admission. A begin-handoff/logout fence therefore closes before
      // any later wallet/social request can overtake it, without making a long
      // login or permission dialog stall unrelated bridge responses.
      final admission = await _bridgeAdmissionCoordinator.admit(
        method,
        payload,
      );

      await _bridgeAdmissionCoordinator.runInRequestContext(
        admission: admission,
        body: () async {
          if (!admission.dispatch) {
            await _resolveBridgePromise(
              id: id,
              value: admission.value,
              error: admission.error,
            );
            return;
          }
          await _dispatchAuthorizedBridgeMessage(
            method: method,
            id: id,
            payload: payload,
          );
        },
      );
    } catch (e, st) {
      // Surface dispatch failures so we don't end up with a silently
      // hung pending promise on the JS side. The id may not have been
      // parsed yet, in which case there is no resolver to call.
      debugPrint('[Usernode JS-channel] dispatch error: $e\n$st');
    }
  }

  Future<void> _dispatchAuthorizedBridgeMessage({
    required String method,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    // Any handler that throws before resolving would otherwise leave
    // the page's JS promise pending forever. Reject here so a bridge caller
    // always settles instead of hanging.
    try {
      await _dispatchBridgeHandler(method, id, payload);
    } catch (e, st) {
      debugPrint(
        '[Usernode JS-channel] handler error method=$method id=$id: '
        '$e\n$st',
      );
      await _resolveBridgePromise(id: id, value: null, error: 'Internal error');
    }
  }

  Future<void> _dispatchBridgeHandler(
    String method,
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (method == 'getNodeAddress') {
      await _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'getNodeAddress',
        body: (identity, _) => identity.address,
      );
    }

    if (method == 'submitTransaction') {
      await _handleSubmitTransaction(id, payload);
    }

    if (method == 'signMessage') {
      await _handleSignMessage(id, payload);
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
      await _resolveBridgePromise(
        id: id,
        value: await _bridgeInfoValue(),
        error: null,
      );
    }

    if (method == 'captureScreenshot') {
      await _handleCaptureScreenshot(id);
    }

    if (method == 'getNodeStatus') {
      await _handleGetNodeStatus(id, payload);
    }

    if (method == 'getWalletState') {
      await _handleGetWalletState(id, payload);
    }

    if (method == 'manageStaking') {
      await _handleManageStaking(id, payload);
    }

    if (method == 'openNativeScreen') {
      await _handleOpenNativeScreen(id, payload);
    }

    if (method == 'getSettingsState') {
      await _handleGetSettingsState(id, payload);
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
      await _handleResetZkChallenge(id, payload);
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

    if (method == 'establishNativeSession') {
      await _handleEstablishNativeSession(id, payload);
    }

    if (method == 'getSocialPushState') {
      await _handleGetSocialPushState(id, payload);
    }

    if (method == 'setSocialPushEnabled') {
      await _handleSetSocialPushEnabled(id, payload);
    }

    if (method == 'claimPendingSocialNotification') {
      await _handleClaimPendingSocialNotification(id, payload);
    }

    if (method == 'ackPendingSocialNotification') {
      await _handleAckPendingSocialNotification(id, payload);
    }
  }

  Future<Map<String, dynamic>> _bridgeInfoValue() async => {
        'version': _bridgeVersion,
        'capabilities': _platformBridgeCapabilities,
        'sessionLifecycleProtocol': 2,
        // Public release identifiers belong in this discovery probe: SV
        // staging cannot bootstrap the production-origin authority but still
        // needs to show which Flutter binary hosts the page.
        ...await _mobileAppBuildInfo(),
      };
}
