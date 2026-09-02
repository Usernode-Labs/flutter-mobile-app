part of '../dapp_webview_screen.dart';

/// Feature capability advertised when the trusted SV shell can enter the
/// retained native ZK identity flow through [trustedNativeScreenRoutes].
const zkIdentityFlowCapability = 'zkIdentityFlow';

/// Native routes the trusted SV top frame may push through
/// `openNativeScreen`. Keeping the wire targets in one registry makes the
/// advertised ZK capability and its dispatch target independently testable.
@visibleForTesting
const trustedNativeScreenRoutes = <String, String>{
  'diagnostics': AppRoutes.diagnostics,
  'benchmark': AppRoutes.deviceBenchmark,
  'httpLogs': AppRoutes.httpDebugLogs,
  'zkIdentity': AppRoutes.zkIdentityDetail,
};

/// Settings/profile/misc bridge methods. Native settings, account state, and
/// actions stay behind trusted SV chrome; the installed app's public release
/// identifiers are also shared with `getBridgeInfo` so staging can display
/// which Flutter binary hosts it.
mixin _BridgeSettings on _DappWebViewScreenStateBase {
  /// `openExternal` JS-channel method: opens the given http(s) URL in the
  /// system browser. Non-web schemes are rejected so pages can't silently
  /// fire intent://, tel:, etc. through this path.
  Future<void> _handleOpenExternal(
      String id, Map<String, dynamic> payload) async {
    final args = payload['args'];
    final url = args is Map<String, dynamic> ? args['url']?.toString() : null;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'openExternal requires an http(s) url',
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _resolveJsPromise(
      id: id,
      value: launched,
      error: launched ? null : 'Could not open URL',
    );
  }

  /// `openNativeScreen` JS-channel method: pushes an allowlisted native
  /// route. Escape hatch for the tooling and hardware-backed identity flow
  /// that stay native. Only the trusted SV origin may drive native navigation
  /// — sub-apps get a rejection.
  Future<void> _handleOpenNativeScreen(
      String id, Map<String, dynamic> payload) async {
    final args = payload['args'];
    final screen =
        args is Map<String, dynamic> ? args['screen']?.toString() : null;
    final route = screen == null ? null : trustedNativeScreenRoutes[screen];
    if (route == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error:
            'Unknown screen; allowed: ${trustedNativeScreenRoutes.keys.join(', ')}',
      );
      return;
    }
    if (!await _isTrustedShortcutOrigin()) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'openNativeScreen is only available to the dapps home',
      );
      return;
    }
    if (!mounted) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'openNativeScreen')) {
      return;
    }
    if (!mounted) return;
    context.push(route);
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  /// Public, device-local build metadata. `getBridgeInfo` includes these two
  /// fields so the Social Vibecoding shell can identify the installed Flutter
  /// binary even on a staging origin, where privileged settings access is
  /// intentionally unavailable. App version/build are public release
  /// identifiers; no account, wallet, or device state is exposed here.
  Future<Map<String, String?>> _mobileAppBuildInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (_) {
      return const {
        'appVersion': null,
        'buildNumber': null,
      };
    }
  }

  /// One JSON shape shared by `getSettingsState` and every settings setter
  /// (each setter resolves with the refreshed state so SV re-renders from a
  /// single source of truth). Mirrors what the native settings screen shows.
  Future<Map<String, dynamic>> _settingsStateSnapshot({
    bool? facematchStrictOverride,
    required SessionIdentityProjection identity,
    required SessionSleepSnapshot sleep,
  }) async {
    // Live probes, not the service's cached combined flag: the granular
    // request methods don't refresh `hasPermissions`, and its legacy
    // notifications&&exactAlarm semantics would mislabel `exactAlarmGranted`.
    bool exactAlarmGranted = false;
    bool? batteryOptDisabled;
    bool notificationsGranted = false;
    String? deviceManufacturer;
    try {
      await PlatformAlarmService.instance.initialize();
      notificationsGranted =
          await PlatformAlarmService.instance.hasNotificationsPermission();
      final alarm =
          await PlatformAlarmService.instance.alarmPermissionsSnapshot();
      exactAlarmGranted = alarm['exactAlarmGranted'] == true;
      batteryOptDisabled = alarm['batteryOptDisabled'] as bool?;
      if (defaultTargetPlatform == TargetPlatform.android) {
        deviceManufacturer =
            await PlatformAlarmService.instance.getDeviceManufacturer();
      }
    } catch (e) {
      debugPrint('[Usernode JS-channel] permission probe failed: $e');
    }

    final mobileAppBuildInfo = await _mobileAppBuildInfo();

    String? nodeVersion;
    String? commitHash;
    String? branch;
    try {
      final env = ref.read(buildEnvProvider);
      nodeVersion = env.version;
      final hash = env.git.commitHash;
      commitHash = hash.length >= 7 ? hash.substring(0, 7) : hash;
      branch = env.git.branch;
    } catch (_) {}

    var facematchStrict = facematchStrictOverride ?? true;
    if (facematchStrictOverride == null) {
      try {
        facematchStrict = await ref
            .read(zkPassportFlowControllerProvider)
            .getFacematchStrict();
      } catch (e) {
        debugPrint('[Usernode JS-channel] facematch setting read failed: $e');
      }
    }

    return {
      'buildInfo': {
        ...mobileAppBuildInfo,
        'nodeVersion': nodeVersion,
        'commitHash': commitHash,
        'branch': branch,
      },
      'nodeSleepEnabled': sleep.enabled,
      'debugMode': ref.read(debugModeProvider),
      'facematchStrict': facematchStrict,
      // Terms moved to the SV web settings (session-authed /challenges-api
      // terms routes) — no native terms state remains.
      'authStatus': identity.status == SessionProjectionStatus.ready
          ? 'ready'
          : 'unauthenticated',
      'permissions': {
        'platform':
            defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
        'exactAlarmGranted': exactAlarmGranted,
        'notificationsGranted': notificationsGranted,
        'batteryOptDisabled': batteryOptDisabled,
        'deviceManufacturer': deviceManufacturer,
      },
    };
  }

  Future<void> _handleGetSettingsState(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'getSettingsState',
        body: (identity, operation) async => _settingsStateSnapshot(
          identity: identity,
          sleep: await operation.readSleep(),
        ),
      );

  Future<void> _handleSetNodeSleepEnabled(
      String id, Map<String, dynamic> payload) async {
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    await _resolveClaimedSessionOperation(
      id: id,
      payload: payload,
      method: 'setNodeSleepEnabled',
      body: (identity, operation) async => _settingsStateSnapshot(
        identity: identity,
        sleep: await operation.setSleepEnabled(enabled),
      ),
    );
  }

  Future<Map<String, dynamic>> _settingsStateForCurrentSession({
    bool? facematchStrictOverride,
  }) async {
    final access = widget._sessionAccess.current;
    if (access.identity.status != SessionProjectionStatus.ready) {
      throw const NativeSessionException(
        'native_session_not_ready',
        'There is no ready native session.',
      );
    }
    return access.operations.run(
      (operation) async => _settingsStateSnapshot(
        identity: access.identity,
        sleep: await operation.readSleep(),
        facematchStrictOverride: facematchStrictOverride,
      ),
    );
  }

  Future<void> _handleSetDebugMode(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setDebugMode')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'setDebugMode')) return;
    await ref.read(debugModeProvider.notifier).set(enabled);
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateForCurrentSession(),
      error: null,
    );
  }

  Future<void> _handleSetFacematchStrict(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setFacematchStrict')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'setFacematchStrict')) {
      return;
    }
    final facematchStrict = await ref
        .read(zkPassportFlowControllerProvider)
        .setFacematchStrict(enabled);
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateForCurrentSession(
        facematchStrictOverride: facematchStrict,
      ),
      error: null,
    );
  }

  /// `resetZkChallenge`: same reset the native settings screen offers.
  /// Confirmation happens web-side; this is the commit.
  Future<void> _handleResetZkChallenge(
    String id,
    Map<String, dynamic> payload,
  ) =>
      _resolveClaimedSessionOperation(
        id: id,
        payload: payload,
        method: 'resetZkChallenge',
        body: (_, __) async {
          if (!mounted) {
            throw const NativeSessionException(
              'native_ui_unavailable',
              'The device proof UI is unavailable.',
            );
          }
          final reset = await resetChallengeState(ref, context);
          if (!reset) {
            throw const NativeSessionException(
              'native_zk_busy',
              'A zkPassport proof is still being processed. '
                  'Try again shortly.',
            );
          }
          if (mounted) {
            context.push(AppRoutes.zkIdentityDetail);
          }
          return true;
        },
      );

  Future<void> _handleRequestPermissions(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'requestPermissions')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'requestPermissions')) {
      return;
    }
    final granted = await PlatformAlarmService.instance.requestPermissions();
    final state = await _settingsStateForCurrentSession();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  Future<void> _handleOpenBatterySettings(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'openBatterySettings')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'openBatterySettings')) {
      return;
    }
    await PlatformAlarmService.instance.openBatteryOptimizationSettings();
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  /// Granular variant of `requestPermissions`: notification permission only.
  /// SV prompts at its own product moments (social push, nudges) without
  /// dragging the user through the alarm/battery chain.
  Future<void> _handleRequestNotificationPermission(String id) async {
    if (!await _requireTrustedChromeOrigin(
        id, 'requestNotificationPermission')) {
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'requestNotificationPermission',
    )) {
      return;
    }
    final granted =
        await PlatformAlarmService.instance.requestNotificationsPermission();
    final state = await _settingsStateForCurrentSession();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  /// Granular variant of `requestPermissions`: exact-alarm + battery only.
  /// Never shows the notification dialog.
  Future<void> _handleRequestAlarmPermissions(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'requestAlarmPermissions')) {
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'requestAlarmPermissions',
    )) {
      return;
    }
    final granted =
        await PlatformAlarmService.instance.requestAlarmPermissions();
    final state = await _settingsStateForCurrentSession();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  /// Deep link to the OS notification settings — the recovery path once the
  /// OS permission dialog is exhausted (denied on iOS, or twice on Android).
  Future<void> _handleOpenNotificationSettings(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'openNotificationSettings')) {
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'openNotificationSettings',
    )) {
      return;
    }
    final opened =
        await PlatformAlarmService.instance.openNotificationSettings();
    await _resolveJsPromise(
      id: id,
      value: opened,
      error: opened ? null : 'Could not open notification settings',
    );
  }

  /// `setAppearance` JS-channel method: SV tells us which appearance it
  /// resolved to, so the NEXT cold launch can open in it.
  ///
  /// THE ONE UNPRIVILEGED METHOD IN THIS MIXIN, deliberately. Every other
  /// one reads or mutates native settings or account state and is gated on
  /// the trusted-origin lease. This carries neither: two enum-ish values
  /// describing a colour. And the launch it exists to fix is the one BEFORE
  /// sign-in — gating it on a privileged lease would make it unavailable in
  /// exactly the case it was added for, which is the whole feature.
  ///
  /// The blast radius of accepting it unprivileged is bounded to a wrong
  /// launch tint for one launch: no data is exposed, the write is
  /// idempotent, and the trusted shell republishes on every boot, so any
  /// value a hosted app managed to set is corrected the next time SV loads.
  ///
  /// `scheme` is RESOLVED by SV (it has already folded its own `system` mode
  /// against the OS preference) and must not be re-resolved here.
  Future<void> _handleSetAppearance(
      String id, Map<String, dynamic> payload) async {
    final args = payload['args'];
    final rawScheme =
        args is Map<String, dynamic> ? args['scheme']?.toString() : null;
    if (rawScheme != 'dark' && rawScheme != 'light') {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: "args.scheme must be 'dark' or 'light'",
      );
      return;
    }
    final scheme =
        rawScheme == 'dark' ? Brightness.dark : Brightness.light;
    // An unparseable colour is not an error: the scheme alone already stops
    // the flash, and SV omits the field when it could not read its own
    // ground. Store null rather than keeping a colour from the old theme.
    final background = AppearanceStorage.parseBackground(
      args is Map<String, dynamic> ? args['background'] : null,
    );
    await AppearanceStorage.save(scheme: scheme, background: background);
    if (mounted) {
      // Adopt it live too, so the native surfaces around the WebView match
      // the page the user is already looking at rather than only matching
      // from the next launch.
      ref.read(themeModeProvider.notifier).adoptPublishedAppearance();
      _applyWebViewBackground();
    }
    await _resolveJsPromise(id: id, value: true, error: null);
  }
}
